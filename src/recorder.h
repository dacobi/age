#pragma once

#include <string>
#include <thread>
#include <mutex>
#include <queue>
#include <atomic>
#include <vector>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/imgutils.h>
}

class Recorder {
public:
    Recorder();
    ~Recorder();

    bool start(int width, int height, int fps, int audio_rate, int audio_channels, const std::string& path);
    void stop();
    
    // Pitch is in bytes (e.g. width * 4 for RGBA)
    void pushVideoFrame(const uint8_t* rgba_pixels, int pitch);
    bool canAcceptVideoFrame();
    
    // interleaved stereo audio (L R L R ...)
    void pushAudioFrames(const float* pcm_data, int num_frames);

    int getFrameCount() const { return frame_count; }
    bool isRecording() const { return recording; }
    double getRecordedElapsedSeconds() const {
        if (!recording) return 0.0;
        auto now = std::chrono::steady_clock::now();
        std::chrono::duration<double> elapsed = now - start_time;
        return elapsed.count();
    }
    int getWidth() const { return width; }
    int getHeight() const { return height; }

private:
    void workerFunc();
    bool setupVideo();
    bool setupAudio();
    void writeVideoFrame(const uint8_t* rgba_pixels, int pitch, int64_t pts);
    void writeAudioFrames(const float* pcm_data, int num_frames);
    void flushEncoder(AVCodecContext* ctx, AVStream* stream);

    std::atomic<bool> recording{false};
    std::atomic<bool> stopping{false};
    std::thread worker_thread;
    std::thread pulse_thread;
    void pulseFunc();
    
    std::mutex video_mutex;
    struct VideoFrameData {
        std::vector<uint8_t> data;
        int64_t pts;
    };
    std::queue<VideoFrameData> video_queue;
    std::chrono::steady_clock::time_point start_time;

    
    std::mutex audio_mutex;
    std::queue<std::vector<float>> audio_queue;

    int width = 0;
    int height = 0;
    int fps = 0;
    int audio_rate = 0;
    int audio_channels = 0;
    std::string path;
    int frame_count = 0;

    AVFormatContext* format_ctx = nullptr;
    AVStream* video_stream = nullptr;
    AVStream* audio_stream = nullptr;
    AVCodecContext* video_codec_ctx = nullptr;
    AVCodecContext* audio_codec_ctx = nullptr;
    SwsContext* sws_ctx = nullptr;
    SwrContext* swr_ctx = nullptr;
    AVFrame* video_frame = nullptr;
    AVFrame* audio_frame = nullptr;
    AVPacket* packet = nullptr;
    
    int64_t next_video_pts = 0;
    int64_t next_audio_pts = 0;
};
