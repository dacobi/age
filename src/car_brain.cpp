#include "car_brain.hpp"
#include <chrono>

using namespace godot;

void CarBrain::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_weights"), &CarBrain::get_weights);
    ClassDB::bind_method(D_METHOD("set_weights", "weights"), &CarBrain::set_weights);
    ClassDB::bind_method(D_METHOD("think", "inputs"), &CarBrain::think);
    ClassDB::bind_method(D_METHOD("mutate", "mutation_rate", "mutation_strength"), &CarBrain::mutate);
    ClassDB::bind_method(D_METHOD("randomize_weights"), &CarBrain::randomize_weights);
}

CarBrain::CarBrain() {
    W1 = Eigen::MatrixXf::Random(hidden_size, input_size);
    b1 = Eigen::VectorXf::Random(hidden_size);
    W2 = Eigen::MatrixXf::Random(output_size, hidden_size);
    b2 = Eigen::VectorXf::Random(output_size);

    std::random_device rd;
    rng.seed(rd());
}

CarBrain::~CarBrain() {
}

void CarBrain::randomize_weights() {
    std::normal_distribution<float> dist(0.0f, 1.0f);
    for (int i = 0; i < W1.size(); ++i) W1(i) = dist(rng);
    for (int i = 0; i < b1.size(); ++i) b1(i) = dist(rng);
    for (int i = 0; i < W2.size(); ++i) W2(i) = dist(rng);
    for (int i = 0; i < b2.size(); ++i) b2(i) = dist(rng);
}

PackedFloat32Array CarBrain::get_weights() const {
    PackedFloat32Array weights;
    int total_weights = W1.size() + b1.size() + W2.size() + b2.size();
    weights.resize(total_weights);

    int idx = 0;
    for (int i = 0; i < W1.size(); ++i) weights[idx++] = W1(i);
    for (int i = 0; i < b1.size(); ++i) weights[idx++] = b1(i);
    for (int i = 0; i < W2.size(); ++i) weights[idx++] = W2(i);
    for (int i = 0; i < b2.size(); ++i) weights[idx++] = b2(i);

    return weights;
}

void CarBrain::set_weights(const PackedFloat32Array &weights) {
    int total_weights = W1.size() + b1.size() + W2.size() + b2.size();
    if (weights.size() != total_weights) {
        ERR_PRINT("Invalid weights size.");
        return;
    }

    int idx = 0;
    for (int i = 0; i < W1.size(); ++i) W1(i) = weights[idx++];
    for (int i = 0; i < b1.size(); ++i) b1(i) = weights[idx++];
    for (int i = 0; i < W2.size(); ++i) W2(i) = weights[idx++];
    for (int i = 0; i < b2.size(); ++i) b2(i) = weights[idx++];
}

PackedFloat32Array CarBrain::think(const PackedFloat32Array &inputs) const {
    if (inputs.size() != input_size) {
        ERR_PRINT("Invalid inputs size.");
        return PackedFloat32Array();
    }

    Eigen::VectorXf x(input_size);
    for (int i = 0; i < input_size; ++i) {
        x(i) = inputs[i];
    }

    Eigen::VectorXf h = (W1 * x + b1).unaryExpr([this](float val) { return relu(val); });
    Eigen::VectorXf y = (W2 * h + b2).unaryExpr([this](float val) { return tanh(val); });

    PackedFloat32Array outputs;
    outputs.resize(output_size);
    for (int i = 0; i < output_size; ++i) {
        outputs[i] = y(i);
    }

    return outputs;
}

void CarBrain::mutate(float mutation_rate, float mutation_strength) {
    std::uniform_real_distribution<float> prob(0.0f, 1.0f);
    std::normal_distribution<float> dist(0.0f, mutation_strength);

    for (int i = 0; i < W1.size(); ++i) {
        if (prob(rng) < mutation_rate) W1(i) += dist(rng);
    }
    for (int i = 0; i < b1.size(); ++i) {
        if (prob(rng) < mutation_rate) b1(i) += dist(rng);
    }
    for (int i = 0; i < W2.size(); ++i) {
        if (prob(rng) < mutation_rate) W2(i) += dist(rng);
    }
    for (int i = 0; i < b2.size(); ++i) {
        if (prob(rng) < mutation_rate) b2(i) += dist(rng);
    }
}
