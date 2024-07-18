import MetalKit

/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 Math utility functions that work, create, and modify vectors, matrices, and quaternions,
 common types developers use for creating 3D graphics with Metal.
 */

/*
 Metal uses column-major matrices and column-vector inputs.

 linear index             c0 c1 c2 c3           Example with reference elements
 --------------     ------------------         ---------------------------------
 0  4  8 12          r0 | 00 10 20 30           sx  10  20   tx
 1  5  9 13    -->   r1 | 01 11 21 31    -->    01  sy  21   ty
 2  6 10 14          r2 | 02 12 22 32           02  12  sz   tz
 3  7 11 15          r3 | 03 13 23 33           03  13  1/d  33

 r = row
 c = column
 s = scale
 t = transform
 d = depth
 */
typealias  quaternion_float = vector_float4

var seed_lo: UInt32
var seed_hi: UInt32  // __uint32_t

func F16ToF32(address: Float16) -> Float {
    return address
}

/*
 func float32_from_float16(i:uint16_t) ->float {
 return F16ToF32((__fp16 *)&i);
 }
 */
func F32ToF16(F32: Float) -> Float16 {
    return Float16(F32)
}

func float16_from_float32(f: Float) -> Float16 {
    return F32ToF16(f)
}

func generate_random_vector(min: Float, max: Float) -> vector_float3 {
    var rand: vector_float3

    let range = max - min
    rand.x = (Double.random(in: 0...1.0) / Double(0x7FFFFFFF)) * range + min
    rand.y = (Double.random(in: 0...1.0) / Double(0x7FFFFFFF)) * range + min
    rand.z = (Double.random(in: 0...1.0) / Double(0x7FFFFFFF)) * range + min

    return rand
}

func seedRand(seed: UInt32) {
    seed_lo = seed
    seed_hi = ~seed
}

func randi() -> Int32 {
    seed_hi = (seed_hi<<16) + (seed_hi>>16)
    seed_hi += seed_lo
    seed_lo += seed_hi
    return seed_hi
}

func randf(x: Float) -> Float {
    return (x * randi() / Float(0x7FFFFFFF))
}

func degrees_from_radians(radians: Float) -> Float {
    return (radians / Float.pi) * 180
}

func radians_from_degrees(degrees: Float) -> Float {
    return (degrees / 180) * Float.pi
}

func vector_make(x: Float, y: Float, z: Float) -> vector_float3 {
    return vector_float3( x, y, z )
}

func vector_lerp( v0: vector_float3, v1: vector_float3, t: Float) -> vector_float3 {
    return ((1 - t) * v0) + (t * v1)
}

func vector_lerp( v0: vector_float4, v1: vector_float4, t: Float) -> vector_float4 {
    return ((1 - t) * v0) + (t * v1)
}

// ------------------------------------------------------------------------------
// matrix_make_rows takes input data with rows of elements.
// This way, the calling code matrix data can look like the rows
// of a matrix made for transforming column vectors.

// Indices are m<column><row>.
func matrix_make_rows(
    m00: Float, m10: Float, m20: Float,
    m01: Float, m11: Float, m21: Float,
    m02: Float, m12: Float, m22: Float) -> matrix_float3x3 {
    return matrix_float3x3(
        vector_float3(m00, m01, m02),      // each line here provides column data
        vector_float3(m10, m11, m12),
        vector_float3(m20, m21, m22)
    )
}

func matrix_make_rows(
    m00: Float, m10: Float, m20: Float, m30: Float,
    m01: Float, m11: Float, m21: Float, m31: Float,
    m02: Float, m12: Float, m22: Float, m32: Float,
    m03: Float, m13: Float, m23: Float, m33: Float,
    ) -> matrix_float3x3 {
    return matrix_float4x4(
        m00, m01, m02, m03,      // each line here provides column data
        m10, m11, m12, m13,
        m20, m21, m22, m23,
        m30, m31, m32, m33
    )
}
// Each arg is a column vector.
func matrix_make_columns(
    col0: vector_float3,
    col1: vector_float3,
    col2: vector_float3) -> matrix_float3x3 {
    return matrix_float3x3( col0, col1, col2 )
}

// Each arg is a column vector.
func matrix_make_columns(
    col0: vector_float4,
    col1: vector_float4,
    col2: vector_float4,
    col3: vector_float4) -> matrix_float4x4 {
    return matrix_float4x4( col0, col1, col2, col3 )
}

func matrix3x3_from_quaternion(q: quaternion_float ) -> matrix_float3x3 {
    let xx = q.x * q.x
    let xy = q.x * q.y
    let xz = q.x * q.z
    let xw = q.x * q.w
    let yy = q.y * q.y
    let yz = q.y * q.z
    let yw = q.y * q.w
    let zz = q.z * q.z
    let zw = q.z * q.w

    // Indices are m<column><row>.
    let m00 = 1 - 2 * (yy + zz)
    let m10 = 2 * (xy - zw)
    let m20 = 2 * (xz + yw)

    let m01 = 2 * (xy + zw)
    let m11 = 1 - 2 * (xx + zz)
    let m21 = 2 * (yz - xw)

    let m02 = 2 * (xz - yw)
    let m12 = 2 * (yz + xw)
    let m22 = 1 - 2 * (xx + yy)

    return matrix_make_rows(m00, m10, m20,
                            m01, m11, m21,
                            m02, m12, m22)
}

func matrix3x3_rotation(radians: Float, axis: vector_float3) -> matrix_float3x3 {
    axis = vector_normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = axis.x, y = axis.y, z = axis.z
    return matrix_make_rows(    ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st,
                                y * x * ci + z * st, ct + y * y * ci, y * z * ci - x * st,
                                z * x * ci - y * st, z * y * ci + x * st, ct + z * z * ci )
}

func matrix3x3_rotation(radians: Float, x: Float, y: Float, z: Float) -> matrix_float3x3 {
    return matrix3x3_rotation(radians, vector_make(x, y, z))
}

func matrix3x3_scale(sx: Float, sy: Float, sz: Float) -> matrix_float3x3 {
    return matrix_make_rows(sx, 0, 0,
                            0, sy, 0,
                            0, 0, sz)
}

func matrix3x3_scale(s: vector_float3) -> matrix_float3x3 {
    return matrix_make_rows(s.x, 0, 0,
                            0, s.y, 0,
                            0, 0, s.z)
}

func matrix3x3_upper_left(m: matrix_float4x4) -> matrix_float3x3 {
    let x = m.columns[0].xyz
    let y = m.columns[1].xyz
    let z = m.columns[2].xyz
    return matrix_make_columns(x, y, z)
}

func matrix_inverse_transpose(m: matrix_float3x3) -> matrix_float3x3 {
    return matrix_invert(matrix_transpose(m))
}

func matrix4x4_from_quaternion(q: quaternion_float) -> matrix_float4x4 {
    let xx = q.x * q.x
    let xy = q.x * q.y
    let xz = q.x * q.z
    let xw = q.x * q.w
    let yy = q.y * q.y
    let yz = q.y * q.z
    let yw = q.y * q.w
    let zz = q.z * q.z
    let zw = q.z * q.w

    // Indices are m<column><row>.
    let m00 = 1 - 2 * (yy + zz)
    let m10 = 2 * (xy - zw)
    let m20 = 2 * (xz + yw)

    let m01 = 2 * (xy + zw)
    let m11 = 1 - 2 * (xx + zz)
    let m21 = 2 * (yz - xw)

    let m02 = 2 * (xz - yw)
    let m12 = 2 * (yz + xw)
    let m22 = 1 - 2 * (xx + yy)

    let matrix = matrix_make_rows(m00, m10, m20, 0,
                                  m01, m11, m21, 0,
                                  m02, m12, m22, 0,
                                  0, 0, 0, 1)
    return matrix
}

func matrix4x4_rotation(radians: Float, axis: vector_float3) -> matrix_float4x4 {
    axis = vector_normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = axis.x, y = axis.y, z = axis.z
    return matrix_make_rows(
        ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st, 0,
        y * x * ci + z * st, ct + y * y * ci, y * z * ci - x * st, 0,
        z * x * ci - y * st, z * y * ci + x * st, ct + z * z * ci, 0,
        0, 0, 0, 1)
}

func matrix4x4_rotation(radians: Float, x: Float, y: Float, z: Float) -> matrix_float4x4 {
    return matrix4x4_rotation(radians, vector_make(x, y, z))
}

func matrix4x4_identity() -> matrix_float4x4 {
    return matrix_make_rows(1, 0, 0, 0,
                            0, 1, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1 )
}

func matrix4x4_scale(sx: Float, sy: Float, sz: Float) -> matrix_float4x4 {
    return matrix_make_rows(sx, 0, 0, 0,
                            0, sy, 0, 0,
                            0, 0, sz, 0,
                            0, 0, 0, 1 )
}

func matrix4x4_scale(s: vector_float3) -> matrix_float4x4 {
    return matrix_make_rows(s.x, 0, 0, 0,
                            0, s.y, 0, 0,
                            0, 0, s.z, 0,
                            0, 0, 0, 1 )
}

func matrix4x4_translation(tx: Float, ty: Float, tz: Float) -> matrix_float4x4 {
    return matrix_make_rows(1, 0, 0, tx,
                            0, 1, 0, ty,
                            0, 0, 1, tz,
                            0, 0, 0, 1 )
}

func matrix4x4_translation(t: vector_float3) -> matrix_float4x4 {
    return matrix_make_rows(1, 0, 0, t.x,
                            0, 1, 0, t.y,
                            0, 0, 1, t.z,
                            0, 0, 0, 1 )
}

func matrix4x4_scale_translation(s: vector_float3, t: vector_float3) -> matrix_float4x4 {
    return matrix_make_rows(s.x, 0, 0, t.x,
                            0, s.y, 0, t.y,
                            0, 0, s.z, t.z,
                            0, 0, 0, 1 )
}

func matrix_look_at_left_hand(eye: vector_float3, target: vector_float3, up: vector_float3) -> matrix_float4x4 {
    let z = vector_normalize(target - eye)
    let x = vector_normalize(vector_cross(up, z))
    let y = vector_cross(z, x)
    let t = vector_make(-vector_dot(x, eye), -vector_dot(y, eye), -vector_dot(z, eye))

    return matrix_make_rows(x.x, x.y, x.z, t.x,
                            y.x, y.y, y.z, t.y,
                            z.x, z.y, z.z, t.z,
                            0, 0, 0, 1 )
}

func matrix_look_at_left_hand(eyeX: Float, eyeY: Float, eyeZ: Float,
                              centerX: Float, centerY: Float, centerZ: Float,
                              upX: Float, upY: Float, upZ: Float) -> matrix_float4x4 {
    let eye = vector_make(eyeX, eyeY, eyeZ)
    let center = vector_make(centerX, centerY, centerZ)
    let up = vector_make(upX, upY, upZ)

    return matrix_look_at_left_hand(eye, center, up)
}

func matrix_look_at_right_hand(eye: vector_float3, target: vector_float3, up: vector_float3) -> matrix_float4x4 {
    let z = vector_normalize(eye - target)
    let x = vector_normalize(vector_cross(up, z))
    let y = vector_cross(z, x)
    let t = vector_make(-vector_dot(x, eye), -vector_dot(y, eye), -vector_dot(z, eye))

    return matrix_make_rows(x.x, x.y, x.z, t.x,
                            y.x, y.y, y.z, t.y,
                            z.x, z.y, z.z, t.z,
                            0, 0, 0, 1 )
}

func matrix_look_at_right_hand(eyeX: Float, eyeY: Float, eyeZ: Float,
                               centerX: Float, centerY: Float, centerZ: Float,
                               upX: Float, upY: Float, upZ: Float) -> matrix_float4x4 {
    let eye = vector_make(eyeX, eyeY, eyeZ)
    let center = vector_make(centerX, centerY, centerZ)
    let up = vector_make(upX, upY, upZ)

    return matrix_look_at_right_hand(eye, center, up)
}

func matrix_ortho_left_hand(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    return matrix_make_rows(
        2 / (right - left), 0, 0, (left + right) / (left - right),
        0, 2 / (top - bottom), 0, (top + bottom) / (bottom - top),
        0, 0, 1 / (farZ - nearZ), nearZ / (nearZ - farZ),
        0, 0, 0, 1 )
}

func matrix_ortho_right_hand(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    return matrix_make_rows(
        2 / (right - left), 0, 0, (left + right) / (left - right),
        0, 2 / (top - bottom), 0, (top + bottom) / (bottom - top),
        0, 0, -1 / (farZ - nearZ), nearZ / (nearZ - farZ),
        0, 0, 0, 1 )
}

func matrix_perspective_left_hand(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovyRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (farZ - nearZ)
    return matrix_make_rows(xs, 0, 0, 0,
                            0, ys, 0, 0,
                            0, 0, zs, -nearZ * zs,
                            0, 0, 1, 0 )
}

func matrix_perspective_right_hand(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovyRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)
    return matrix_make_rows(xs, 0, 0, 0,
                            0, ys, 0, 0,
                            0, 0, zs, nearZ * zs,
                            0, 0, -1, 0 )
}

func matrix_perspective_frustum_right_hand(l: Float, r: Float, b: Float, t: Float, n: Float, f: Float) -> matrix_float4x4 {
    return matrix_make_rows(
        2 * n / (r - l), 0, (r + l) / (r - l), 0,
        0, 2 * n / (t - b), (t + b) / (t - b), 0,
        0, 0, -f / (f - n), -f * n  / (f - n),
        0, 0, -1, 0 )
}

func matrix_inverse_transpose(m: matrix_float4x4) -> matrix_float4x4 {
    return matrix_invert(matrix_transpose(m))
}

func quaternion(x: Float, y: Float, z: Float, w: Float) -> quaternion_float {
    return quaternion_float( x, y, z, w )
}

func quaternion(v: vector_float3, w: Float) -> quaternion_float {
    return quaternion_float( v.x, v.y, v.z, w )
}

func quaternion_identity() -> quaternion_float {
    return quaternion(0, 0, 0, 1)
}

func quaternion_from_axis_angle(axis: vector_float3, radians: Float) -> quaternion_float {
    let t = radians * 0.5
    return quaternion(axis.x * sinf(t), axis.y * sinf(t), axis.z * sinf(t), cosf(t))
}

func quaternion_from_euler(euler: vector_float3) -> quaternion_float {
    let q

    let cx = cosf(euler.x / 2.f)
    let cy = cosf(euler.y / 2.f)
    let cz = cosf(euler.z / 2.f)
    let sx = sinf(euler.x / 2.f)
    let sy = sinf(euler.y / 2.f)
    let sz = sinf(euler.z / 2.f)

    q.w = cx * cy * cz + sx * sy * sz
    q.x = sx * cy * cz - cx * sy * sz
    q.y = cx * sy * cz + sx * cy * sz
    q.z = cx * cy * sz - sx * sy * cz

    return q
}

func quaternion(m: matrix_float3x3) -> quaternion_float {
    let m00 = m.columns[0].x
    let m11 = m.columns[1].y
    let m22 = m.columns[2].z
    let x = sqrtf(1 + m00 - m11 - m22) * 0.5
    let y = sqrtf(1 - m00 + m11 - m22) * 0.5
    let z = sqrtf(1 - m00 - m11 + m22) * 0.5
    let w = sqrtf(1 + m00 + m11 + m22) * 0.5
    return quaternion(x, y, z, w)
}

func quaternion(m: matrix_float4x4) -> quaternion_float {
    return quaternion(matrix3x3_upper_left(m))
}

func quaternion_length(q: quaternion_float) -> float {
    //  Return sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w);.
    return vector_length(q)
}

func quaternion_length_squared(q: quaternion_float) -> float {
    //  Return q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w;.
    return vector_length_squared(q)
}

func quaternion_axis(q: quaternion_float) -> vector_float3 {
    // This query doesn't make sense if w > 1,  so force it to a unit
    // quaternion which returns something sensible.
    if q.w > 1.0 {
        q = quaternion_normalize(q)
    }

    let axisLen = sqrtf(1 - q.w * q.w)

    if axisLen < 1e-5 {
        // At lengths this small, direction is arbitrary.
        return vector_make(1, 0, 0)
    } else {
        return vector_make(q.x / axisLen, q.y / axisLen, q.z / axisLen)
    }
}

func quaternion_angle(q: quaternion_float) -> float {
    return 2 * acosf(q.w)
}

func quaternion_normalize(q: quaternion_float) -> quaternion_float {
    //  Return q / quaternion_length(q);.
    return vector_normalize(q)
}

func quaternion_inverse(q: quaternion_float) -> quaternion_float {
    return quaternion_conjugate(q) / quaternion_length_squared(q)
}

func quaternion_conjugate(q: quaternion_float) -> quaternion_float {
    return quaternion(-q.x, -q.y, -q.z, q.w)
}

func quaternion_multiply(q0: quaternion_float, q1: quaternion_float) -> quaternion_float {
    var q: quaternion_float

    q.x = q0.w*q1.x + q0.x*q1.w + q0.y*q1.z - q0.z*q1.y
    q.y = q0.w*q1.y - q0.x*q1.z + q0.y*q1.w + q0.z*q1.x
    q.z = q0.w*q1.z + q0.x*q1.y - q0.y*q1.x + q0.z*q1.w
    q.w = q0.w*q1.w - q0.x*q1.x - q0.y*q1.y - q0.z*q1.z
    return q
}

func quaternion_slerp(q0: quaternion_float, q1: quaternion_float, t: Float) -> quaternion_float {
    var q: quaternion_float

    let cosHalfTheta = vector_dot(q0, q1)
    if fabs(cosHalfTheta) >= 1.f {
        return q0
    }

    let halfTheta = acosf(cosHalfTheta)
    let sinHalfTheta = sqrtf(1.0 - cosHalfTheta * cosHalfTheta)
    if fabs(sinHalfTheta) < 0.001 {    // q0 & q1 180 degrees aren't defined.
        return q0*0.5 + q1*0.5
    }
    let srcWeight = sin((1 - t) * halfTheta) / sinHalfTheta
    let dstWeight = sin(t * halfTheta) / sinHalfTheta

    q = srcWeight*q0 + dstWeight*q1

    return q
}

func quaternion_rotate_vector(q: quaternion_float, v: vector_float3) -> vector_float3 {
    let qp = vector_make(q.x, q.y, q.z)
    let w = q.w
    return 2 * vector_dot(qp, v) * qp +
        ((w * w) - vector_dot(qp, qp)) * v +
        2 * w * vector_cross(qp, v)
}

func quaternion_from_matrix3x3(m: matrix_float3x3) -> quaternion_float {
    var q: quaternion_float

    let trace = 1 + m.columns[0][0] + m.columns[1][1] + m.columns[2][2]

    if trace > 0 {
        let diagonal = sqrt(trace) * 2.0

        q.x = (m.columns[2][1] - m.columns[1][2]) / diagonal
        q.y = (m.columns[0][2] - m.columns[2][0]) / diagonal
        q.z = (m.columns[1][0] - m.columns[0][1]) / diagonal
        q.w = diagonal / 4.0

    } else if (m.columns[0][0] > m.columns[1][1] ) &&
                    (m.columns[0][0] > m.columns[2][2]) {

        let diagonal = sqrt(1.0 + m.columns[0][0] - m.columns[1][1] -  m.columns[2][2]) * 2.0

        q.x = diagonal / 4.0
        q.y = (m.columns[0][1] + m.columns[1][0]) / diagonal
        q.z = (m.columns[0][2] + m.columns[2][0]) / diagonal
        q.w = (m.columns[2][1] - m.columns[1][2]) / diagonal

    } else if m.columns[1][1] >  m.columns[2][2] {

        let diagonal = sqrt(1.0 + m.columns[1][1] - m.columns[0][0] - m.columns[2][2]) * 2.0

        q.x = (m.columns[0][1] + m.columns[1][0]) / diagonal
        q.y = diagonal / 4.0
        q.z = (m.columns[1][2] + m.columns[2][1]) / diagonal
        q.w = (m.columns[0][2] - m.columns[2][0]) / diagonal

    } else {

        let diagonal = sqrt(1.0 + m.columns[2][2] - m.columns[0][0] - m.columns[1][1]) * 2.0

        q.x = (m.columns[0][2] + m.columns[2][0]) / diagonal
        q.y = (m.columns[1][2] + m.columns[2][1]) / diagonal
        q.z = diagonal / 4.0
        q.w = (m.columns[1][0] - m.columns[0][1]) / diagonal
    }

    q = quaternion_normalize(q)
    return q
}

func quaternion_from_direction_vectors(forward: vector_float3, up: vector_float3, right_handed: int) -> quaternion_float {

    forward = vector_normalize(forward)
    up = vector_normalize(up)

    let side = vector_normalize(vector_cross(up, forward))

    let m = matrix_float3x3( side, up, forward )

    let q = quaternion_from_matrix3x3(m)

    if right_handed {
        q = q.yxwz
        q.xw = -q.xw
    }

    q = vector_normalize(q)

    return q
}

func quaternion_from_direction_vectors_right_hand(forward: vector_float3, up: vector_float3) -> quaternion_float {

    return quaternion_from_direction_vectors(forward, up, 1)
}

func quaternion_from_direction_vectors_left_hand(forward: vector_float3, up: vector_float3) -> quaternion_float {

    return quaternion_from_direction_vectors(forward, up, 0)
}

func forward_direction_vector_from_quaternion(q: quaternion_float) -> vector_float3 {
    var direction: vector_float3
    direction.x = 2.0 * (q.x*q.z - q.w*q.y)
    direction.y = 2.0 * (q.y*q.z + q.w*q.x)
    direction.z = 1.0 - 2.0 * ((q.x * q.x) + (q.y * q.y))

    direction = vector_normalize(direction)
    return direction
}

func up_direction_vector_from_quaternion(q: quaternion_float) -> vector_float3 {
    var direction: vector_float3
    direction.x = 2.0 * (q.x*q.y + q.w*q.z)
    direction.y = 1.0 - 2.0 * (q.x*q.x + q.z*q.z)
    direction.z = 2.0 * (q.y*q.z - q.w*q.x)

    direction = vector_normalize(direction)
    // Negate for a right-handed coordinate system.
    return direction
}

func right_direction_vector_from_quaternion(q: quaternion_float) -> vector_float3 {
    var direction: vector_float3
    direction.x = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    direction.y = 2.0 * (q.x * q.y - q.w * q.z)
    direction.z = 2.0 * (q.x * q.z + q.w * q.y)

    direction = vector_normalize(direction)
    // Negate for a right-handed coordinate system.
    return direction
}
