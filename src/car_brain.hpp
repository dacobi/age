#ifndef CAR_BRAIN_HPP
#define CAR_BRAIN_HPP

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <Eigen/Dense>
#include <random>

namespace godot {

class CarBrain : public Node {
    GDCLASS(CarBrain, Node)

private:
    Eigen::MatrixXf W1;
    Eigen::VectorXf b1;
    Eigen::MatrixXf W2;
    Eigen::VectorXf b2;

    int input_size = 17;
    int hidden_size = 8;
    int output_size = 5;

    std::mt19937 rng;

    PackedFloat32Array _get_weights() const;
    void _set_weights(const PackedFloat32Array &weights);
    PackedFloat32Array _think(const PackedFloat32Array &inputs) const;
    void _mutate(float mutation_rate, float mutation_strength);

    float relu(float x) const { return std::max(0.0f, x); }
    float tanh(float x) const { return std::tanh(x); }

protected:
    static void _bind_methods();

public:
    CarBrain();
    ~CarBrain();

    PackedFloat32Array get_weights() const;
    void set_weights(const PackedFloat32Array &weights);
    PackedFloat32Array think(const PackedFloat32Array &inputs) const;
    void mutate(float mutation_rate, float mutation_strength);
    void randomize_weights();
};

} // namespace godot

#endif // CAR_BRAIN_HPP
