from matmul import *
import random

random.seed(0)

def Toeplitz(A, B):
    """
    Create a Toeplitz matrix for convolution.
    
    Each row picks a 3x3 patch from 5x5 image A.
    """
    img_rows, img_cols = len(A), len(A[0])
    kernel_rows, kernel_cols = len(B), len(B[0])

    out_rows = img_rows - kernel_rows + 1
    out_cols = img_cols - kernel_cols + 1

    if out_rows <= 0 or out_cols <= 0:
        raise ValueError("Kernel is too large for the input image")

    toeplitz_matrix = []

    for i in range(out_rows):
        for j in range(out_cols):
            row = []
            for ki in range(kernel_rows):
                for kj in range(kernel_cols):
                    row.append(A[i + ki][j + kj])
            toeplitz_matrix.append(row)
    
    return toeplitz_matrix  # Shape: (out_rows*out_cols) x (kernel_rows*kernel_cols)

def flatten_matrix(matrix):
    return [elem for row in matrix for elem in row]

def reshape_vector(vector, rows, cols):
    return [vector[i * cols:(i + 1) * cols] for i in range(rows)]

def convOneChannel(A, B, n=8, es =1,posit=True):
    """
    Perform valid convolution using Toeplitz matrix trick.
    A: 2D input image
    B: 2D kernel
    """
    toeplitz = Toeplitz(A, B)             # Shape: (9 x 9) for 5x5 image and 3x3 kernel
    kernel_flat = flatten_matrix(B)       # Shape: (9,)
    kernel_vec = [[val] for val in kernel_flat]  # Shape: (9 x 1)
    
    if(posit):
        conv_out = matmul_posit(toeplitz, kernel_vec,n=n,es=es)      # Shape: (9 x 1)
    else:
        conv_out = matmul(toeplitz, kernel_vec)      # Shape: (9 x 1)
    conv_flat = [val[0] for val in conv_out]     # Flatten to (9,)
    
    out_rows = len(A) - len(B) + 1
    out_cols = len(A[0]) - len(B[0]) + 1

    return reshape_vector(conv_flat, out_rows, out_cols)

def conv2D(A, B, n=8, es=1, posit=True):
    """
    Perform 2D convolution over multiple input and output channels.

    Args:
        A (list): Input image with shape [Cin][H][W]
        B (list): Weights with shape [Cout][Cin][Kh][Kw]
        n, es (int): Posit parameters
        posit (bool): Use posit or not

    Returns:
        list: Output feature maps of shape [Cout][H-Kh+1][W-Kw+1]
    """
    Cin = len(A)
    Cout = len(B)
    H, W = len(A[0]), len(A[0][0])
    Kh, Kw = len(B[0][0]), len(B[0][0][0])

    out_H = H - Kh + 1
    out_W = W - Kw + 1

    # Initialize output feature maps
    if(posit):
        output = [[[PCPosit(0,mode='bits',nbits=n,es=es) for _ in range(out_W)] for _ in range(out_H)] for _ in range(Cout)]
    else:
        output = [[[0 for _ in range(out_W)] for _ in range(out_H)] for _ in range(Cout)]
    for out_ch in range(Cout):
        # Initialize accumulator for this output channel
        if(posit):
            accum = [[PCPosit(0,mode='bits',nbits=n,es=es) for _ in range(out_W)] for _ in range(out_H)]
        else:
            accum = [[0 for _ in range(out_W)] for _ in range(out_H)]
        for in_ch in range(Cin):
            # Convolve input channel with corresponding kernel
            conv = convOneChannel(A[in_ch], B[out_ch][in_ch], n=n, es=es, posit=posit)

            # Accumulate over input channels
            for i in range(out_H):
                for j in range(out_W):
                    accum[i][j] = accum[i][j] + conv[i][j]

        output[out_ch] = accum

    return output


# Example usage
if __name__ == '__main__':
    n = 8
    es = 1
    
    def generate_random_tensor(shape, low=0, high=4):
        """
        Recursively generates a nested list (tensor) of given shape with random integers.
        
        Args:
            shape (tuple): Desired shape, e.g., (3, 5, 5)
            low (int): Minimum random value (inclusive)
            high (int): Maximum random value (inclusive)
        
        Returns:
            list: Nested list of random integers with specified shape
        """
        if len(shape) == 0:
            return random.randint(low, high)
        return [generate_random_tensor(shape[1:], low, high) for _ in range(shape[0])]

    A = generate_random_tensor((3, 5, 5))       # 3 input channels
    B = generate_random_tensor((2, 3, 3, 3))    # 2 filters, each with 3x3x3 kernel

    
    A_posit = convertMatrixToPOSIT(A,n=n,es=es)
    B_posit = convertMatrixToPOSIT(B,n=n,es=es)

    print(np.array(A).shape)
    print(np.array(B).shape)
    s = time.time()
    result = conv2D(A, B, posit=False)
    # mat_print(result)
    e = time.time()
    print(e-s)
    s = time.time()
    result = conv2D(A_posit, B_posit, n = n, es = es)
    e = time.time()
    print(e-s)
    # print("\nConvolution Result:")
    # mat_print(result)