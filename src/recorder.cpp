#include "recorder.h"
#include <iostream>
#include <chrono>
#include <pulse/simple.h>
#include <pulse/error.h>

Recorder::Recorder() {}

Recorder::~Recorder() {
    stop();
}

bool Recorder::start(int w, int h, int f, int a_rate, int a_channels, const std::string& p) {
    if (recording) return false;
    
    // Enforce even dimensions for yuv420p
    width = w & ~1;
    height = h & ~1;
    fps = f;
    audio_rate = a_rate;
    audio_channels = a_channels;
    path = p;
    frame_count = 0;
    
    avformat_alloc_output_context2(&format_ctx, nullptr, nullptr, path.c_str());
    if (!format_ctx) {
        std::cerr << "Could not deduce output format from file extension: " << path << std::endl;
        return false;
    }

    if (!setupVideo() || !setupAudio()) {
        std::cerr << "Failed to setup streams." << std::endl;
        return false;
    }

    if (!(format_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&format_ctx->pb, path.c_str(), AVIO_FLAG_WRITE) < 0) {
            std::cerr << "Could not open output file: " << path << std::endl;
            return false;
        }
    }

    if (avformat_write_header(format_ctx, nullptr) < 0) {
        std::cerr << "Error occurred when opening output file" << std::endl;
        return false;
    }

    recording = true;
    frame_count = 0;
    next_video_pts = 0;
    next_audio_pts = 0;
    start_time = std::chrono::steady_clock::now();
    stopping = false;
    worker_thread = std::thread(&Recorder::workerFunc, this);
    pulse_thread = std::thread(&Recorder::pulseFunc, this);
    
    return true;
}

bool Recorder::setupVideo() {
    const AVCodec* codec = nullptr;
    if (path.find(".mp4") != std::string::npos) {
        codec = avcodec_find_encoder_by_name("libx264");
        if (!codec) codec = avcodec_find_encoder_by_name("h264_nvenc");
    } else if (path.find(".ogv") != std::string::npos) {
        codec = avcodec_find_encoder_by_name("libtheora");
    }
    if (!codec) codec = avcodec_find_encoder(format_ctx->oformat->video_codec);
    if (!codec) return false;

    video_stream = avformat_new_stream(format_ctx, codec);
    if (!video_stream) return false;

    video_codec_ctx = avcodec_alloc_context3(codec);
    video_codec_ctx->width = width;
    video_codec_ctx->height = height;
    video_codec_ctx->time_base = {1, fps};
    video_stream->time_base = video_codec_ctx->time_base;
    video_codec_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    video_codec_ctx->bit_rate = 4000000;
    video_codec_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    if (codec->id == AV_CODEC_ID_H264) {
        av_opt_set(video_codec_ctx->priv_data, "preset", "fast", 0);
    }

    if (avcodec_open2(video_codec_ctx, codec, nullptr) < 0) return false;
    avcodec_parameters_from_context(video_stream->codecpar, video_codec_ctx);

    video_frame = av_frame_alloc();
    video_frame->format = video_codec_ctx->pix_fmt;
    video_frame->width = video_codec_ctx->width;
    video_frame->height = video_codec_ctx->height;
    av_frame_get_buffer(video_frame, 0);

    sws_ctx = sws_getContext(width, height, AV_PIX_FMT_RGBA,
                             width, height, AV_PIX_FMT_YUV420P,
                             SWS_BILINEAR, nullptr, nullptr, nullptr);
    return true;
}

bool Recorder::setupAudio() {
    const AVCodec* codec = nullptr;
    if (path.find(".mp4") != std::string::npos) {
        codec = avcodec_find_encoder_by_name("aac");
    } else if (path.find(".ogv") != std::string::npos) {
        codec = avcodec_find_encoder_by_name("libvorbis");
    }
    if (!codec) codec = avcodec_find_encoder(format_ctx->oformat->audio_codec);
    if (!codec) return false;

    audio_stream = avformat_new_stream(format_ctx, codec);
    if (!audio_stream) return false;

    audio_codec_ctx = avcodec_alloc_context3(codec);
    audio_codec_ctx->sample_fmt = codec->sample_fmts ? codec->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
    audio_codec_ctx->bit_rate = 128000;
    audio_codec_ctx->sample_rate = audio_rate;
    // Set layout
    AVChannelLayout ch_layout;
    av_channel_layout_default(&ch_layout, audio_channels);
    av_channel_layout_copy(&audio_codec_ctx->ch_layout, &ch_layout);

    audio_codec_ctx->time_base = {1, audio_rate};
    audio_stream->time_base = audio_codec_ctx->time_base;

    audio_codec_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    if (avcodec_open2(audio_codec_ctx, codec, nullptr) < 0) return false;
    avcodec_parameters_from_context(audio_stream->codecpar, audio_codec_ctx);

    audio_frame = av_frame_alloc();
    audio_frame->format = audio_codec_ctx->sample_fmt;
    av_channel_layout_copy(&audio_frame->ch_layout, &ch_layout);
    audio_frame->sample_rate = audio_codec_ctx->sample_rate;
    audio_frame->nb_samples = audio_codec_ctx->frame_size;
    if (audio_frame->nb_samples == 0) audio_frame->nb_samples = 1024; // Default for some codecs
    av_frame_get_buffer(audio_frame, 0);

    AVChannelLayout in_ch_layout;
    av_channel_layout_default(&in_ch_layout, audio_channels);
    swr_alloc_set_opts2(&swr_ctx, &audio_codec_ctx->ch_layout, audio_codec_ctx->sample_fmt, audio_codec_ctx->sample_rate,
                                 &in_ch_layout, AV_SAMPLE_FMT_FLT, audio_rate, 0, nullptr);
    swr_init(swr_ctx);
    
    packet = av_packet_alloc();
    return true;
}

void Recorder::stop() {
    if (!recording) return;
    stopping = true;
    if (worker_thread.joinable()) worker_thread.join();
    if (pulse_thread.joinable()) pulse_thread.join();
    
    recording = false;

    av_write_trailer(format_ctx);

    if (video_codec_ctx) avcodec_free_context(&video_codec_ctx);
    if (audio_codec_ctx) avcodec_free_context(&audio_codec_ctx);
    if (video_frame) av_frame_free(&video_frame);
    if (audio_frame) av_frame_free(&audio_frame);
    if (packet) av_packet_free(&packet);
    if (sws_ctx) sws_freeContext(sws_ctx);
    if (swr_ctx) swr_free(&swr_ctx);

    if (!(format_ctx->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&format_ctx->pb);
    }
    avformat_free_context(format_ctx);
    format_ctx = nullptr;
}

bool Recorder::canAcceptVideoFrame() {
    std::lock_guard<std::mutex> lock(video_mutex);
    if (video_queue.size() >= 1) return false;
    
    auto now = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed = now - start_time;
    int64_t pts = (int64_t)(elapsed.count() * fps);
    return pts >= next_video_pts;
}

void Recorder::pushVideoFrame(const uint8_t* rgba_pixels, int pitch) {
    if (!recording || stopping) return;
    auto now = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed = now - start_time;
    int64_t pts = (int64_t)(elapsed.count() * fps);
    
    if (pts < next_video_pts) {
        pts = next_video_pts;
    }
    next_video_pts = pts + 1;
    
    int data_size = pitch * height;
    std::vector<uint8_t> data(rgba_pixels, rgba_pixels + data_size);
    std::lock_guard<std::mutex> lock(video_mutex);
    video_queue.push({std::move(data), pts});
}

void Recorder::pushAudioFrames(const float* pcm_data, int num_frames) {
    if (!recording || stopping) return;
    std::vector<float> data(pcm_data, pcm_data + num_frames * audio_channels);
    std::lock_guard<std::mutex> lock(audio_mutex);
    audio_queue.push(std::move(data));
}

void Recorder::workerFunc() {
    std::vector<float> audio_buffer;
    
    while (recording) {
        bool idle = true;
        
        VideoFrameData v_data;
        bool has_v_data = false;
        {
            std::lock_guard<std::mutex> lock(video_mutex);
            if (!video_queue.empty()) {
                v_data = std::move(video_queue.front());
                video_queue.pop();
                has_v_data = true;
            }
        }
        if (has_v_data) {
            writeVideoFrame(v_data.data.data(), width * 4, v_data.pts);
            idle = false;
        }
        
        {
            std::lock_guard<std::mutex> lock(audio_mutex);
            while (!audio_queue.empty()) {
                auto& a_data = audio_queue.front();
                audio_buffer.insert(audio_buffer.end(), a_data.begin(), a_data.end());
                audio_queue.pop();
                idle = false;
            }
        }
        
        int frame_size = audio_frame->nb_samples * audio_channels;
        while (audio_buffer.size() >= (size_t)frame_size) {
            writeAudioFrames(audio_buffer.data(), audio_frame->nb_samples);
            audio_buffer.erase(audio_buffer.begin(), audio_buffer.begin() + frame_size);
            idle = false;
        }

        if (stopping) {
            bool v_empty;
            {
                std::lock_guard<std::mutex> lock(video_mutex);
                v_empty = video_queue.empty();
            }
            if (v_empty && !has_v_data && audio_buffer.size() < (size_t)frame_size) {
                break; // Finished draining
            }
        }

        if (idle && !stopping) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
    
    // Flush encoders
    flushEncoder(video_codec_ctx, video_stream);
    flushEncoder(audio_codec_ctx, audio_stream);
}

void Recorder::pulseFunc() {
    pa_sample_spec ss;
    ss.format = PA_SAMPLE_FLOAT32LE;
    ss.rate = audio_rate;
    ss.channels = audio_channels;

    pa_buffer_attr attr;
    attr.maxlength = (uint32_t)-1;
    attr.tlength = (uint32_t)-1;
    attr.prebuf = (uint32_t)-1;
    attr.minreq = (uint32_t)-1;
    // Force 10ms latency (100th of a second)
    attr.fragsize = (ss.rate * ss.channels * sizeof(float)) / 100;

    int error;
    pa_simple *s = pa_simple_new(NULL, "GodotRecorder", PA_STREAM_RECORD, "@DEFAULT_MONITOR@", "Record", &ss, NULL, &attr, &error);
    
    if (!s) {
        std::cerr << "PulseAudio connection failed: " << pa_strerror(error) << std::endl;
        return;
    }

    const int BUF_SIZE = 4096;
    float buffer[BUF_SIZE];

    while (recording && !stopping) {
        if (pa_simple_read(s, buffer, sizeof(buffer), &error) < 0) {
            std::cerr << "PulseAudio read failed: " << pa_strerror(error) << std::endl;
            break;
        }
        pushAudioFrames(buffer, BUF_SIZE / audio_channels);
    }

    pa_simple_free(s);
}

void Recorder::writeVideoFrame(const uint8_t* rgba_pixels, int pitch, int64_t pts) {
    av_frame_make_writable(video_frame);
    const uint8_t* inData[1] = { rgba_pixels };
    int inLinesize[1] = { pitch };
    sws_scale(sws_ctx, inData, inLinesize, 0, height, video_frame->data, video_frame->linesize);

    video_frame->pts = pts;
    frame_count++;

    int ret = avcodec_send_frame(video_codec_ctx, video_frame);
    if (ret < 0) return;
    
    while (ret >= 0) {
        ret = avcodec_receive_packet(video_codec_ctx, packet);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) break;
        
        av_packet_rescale_ts(packet, video_codec_ctx->time_base, video_stream->time_base);
        packet->stream_index = video_stream->index;
        av_interleaved_write_frame(format_ctx, packet);
        av_packet_unref(packet);
    }
}

void Recorder::writeAudioFrames(const float* pcm_data, int num_frames) {
    av_frame_make_writable(audio_frame);
    const uint8_t* inData[1] = { (const uint8_t*)pcm_data };
    swr_convert(swr_ctx, audio_frame->data, audio_frame->nb_samples, inData, num_frames);
    
    audio_frame->pts = next_audio_pts;
    next_audio_pts += audio_frame->nb_samples;

    int ret = avcodec_send_frame(audio_codec_ctx, audio_frame);
    if (ret < 0) {
        static int error_prints = 0;
        if (error_prints < 10) {
            std::cerr << "Recorder: Failed to send audio frame: " << ret << std::endl;
            error_prints++;
        }
        return;
    }
    
    while (ret >= 0) {
        ret = avcodec_receive_packet(audio_codec_ctx, packet);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) break;
        
        av_packet_rescale_ts(packet, audio_codec_ctx->time_base, audio_stream->time_base);
        packet->stream_index = audio_stream->index;
        av_interleaved_write_frame(format_ctx, packet);
        av_packet_unref(packet);
    }
}

void Recorder::flushEncoder(AVCodecContext* ctx, AVStream* stream) {
    if (!ctx) return;
    avcodec_send_frame(ctx, nullptr);
    while (true) {
        int ret = avcodec_receive_packet(ctx, packet);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) break;
        av_packet_rescale_ts(packet, ctx->time_base, stream->time_base);
        packet->stream_index = stream->index;
        av_interleaved_write_frame(format_ctx, packet);
        av_packet_unref(packet);
    }
}
