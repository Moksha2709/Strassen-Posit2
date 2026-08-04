from converters import *
from sgposit.pcposit import PCPosit
import time
import random

def matmul(a, b):
    # Helper to check if a is a list of lists (2D)
    def is_matrix(x):
        return isinstance(x, list) and isinstance(x[0], list)

    # 1D × 1D (dot product)
    if isinstance(a[0], (int, float)) and isinstance(b[0], (int, float)):
        if len(a) != len(b):
            raise ValueError("Vectors must be same length for dot product")
        result = 0
        for i in range(len(a)):
            result += a[i] * b[i]
        return result

    # 2D × 1D (matrix-vector)
    if is_matrix(a) and isinstance(b[0], (int, float)):
        rows_a, cols_a = len(a), len(a[0])
        if cols_a != len(b):
            raise ValueError("Matrix columns must match vector size")
        result = []
        for i in range(rows_a):
            val = 0
            for k in range(cols_a):
                val += a[i][k] * b[k]
            result.append(val)
        return result

    # 2D × 2D (matrix-matrix)
    if is_matrix(a) and is_matrix(b):
        rows_a, cols_a = len(a), len(a[0])
        rows_b, cols_b = len(b), len(b[0])
        if cols_a != rows_b:
            raise ValueError("A columns must match B rows for matrix multiplication")

        result = [[0 for _ in range(cols_b)] for _ in range(rows_a)]
        for i in range(rows_a):
            for j in range(cols_b):
                acc = 0
                for k in range(cols_a):
                    acc += a[i][k] * b[k][j]
                result[i][j] = acc
        return result

    # Unsupported or inconsistent input
    raise TypeError(f"Unsupported input shapes: {type(a)}, {type(b)}")


# def matmul_posit(a, b,n=8,es=1):
#     # Get dimensions
#     rows_a = len(a)
#     cols_a = len(a[0])
#     rows_b = len(b)
#     cols_b = len(b[0])
    
#     # Check if multiplication is possible
#     if cols_a != rows_b:
#         raise ValueError("Cannot multiply matrices: columns of A must equal rows of B")
    
#     # Initialize result matrix with zeros
#     result = [[PCPosit(0,mode='bits',nbits=n,es=es) for _ in range(cols_b)] for _ in range(rows_a)]
    
#     # Perform matrix multiplication
#     for i in range(rows_a):
#         for j in range(cols_b):
#             for k in range(cols_a):
#                 result[i][j] = result[i][j] + (a[i][k] * b[k][j])
    
#     return result 

def matmul_posit(a, b, n=8, es=1):
    # Helper to check if a is a list of lists (2D)
    def is_matrix(x):
        return isinstance(x, list) and isinstance(x[0], list)

    # 1D × 1D (dot product)
    if isinstance(a[0], (int, float,PCPosit)) and isinstance(b[0], (int, float,PCPosit)):
        if len(a) != len(b):
            raise ValueError("Vectors must be same length for dot product")
        result = PCPosit(0, mode='bits',nbits=n, es=es)
        for i in range(len(a)):
            result = result + a[i] * b[i]
        return result

    # 2D × 1D (matrix-vector)
    if is_matrix(a) and isinstance(b[0], (int, float,PCPosit)):
        rows_a, cols_a = len(a), len(a[0])
        if cols_a != len(b):
            raise ValueError("Matrix columns must match vector size")
        result = []
        for i in range(rows_a):
            val = PCPosit(0,mode='bits',nbits=n,es=es)
            for k in range(cols_a):
                val = val + a[i][k] * b[k]
            result.append(val)
        return result
    if is_matrix(b) and isinstance(a[0], (int, float,PCPosit)):
        rows_a, cols_a = len(b), len(b[0])
        if cols_a != len(a):
            raise ValueError("Matrix columns must match vector size")
        result = []
        for i in range(rows_a):
            val = PCPosit(0,mode='bits',nbits=n,es=es)
            for k in range(cols_a):
                val = val + b[i][k] * a[k]
            result.append(val)
        return result
    # 2D × 2D (matrix-matrix)
    if is_matrix(a) and is_matrix(b):
        rows_a, cols_a = len(a), len(a[0])
        rows_b, cols_b = len(b), len(b[0])
        if cols_a != rows_b:
            raise ValueError("A columns must match B rows for matrix multiplication")

        result = [[PCPosit(0,mode='bits',nbits=n,es=es) for _ in range(cols_b)] for _ in range(rows_a)]
        for i in range(rows_a):
            for j in range(cols_b):
                acc = PCPosit(0,mode='bits',nbits=n,es=es)
                for k in range(cols_a):
                    acc = acc + a[i][k] * b[k][j]
                result[i][j] = acc
        return result

    # Unsupported or inconsistent input
    raise TypeError(f"Unsupported input shapes: {type(a)}, {type(b)}")



# def mat_print(A):
#     for i in A:
#         for j in i:
#             print(f'{j}',end=" ")
#         print()
def mat_print(A, indent=0):
    """
    Recursively print a nested list (tensor) with proper formatting.

    Args:
        A (list or scalar): The nested list to print
        indent (int): Indentation level for nested blocks
    """
    if isinstance(A, list):
        if all(not isinstance(sub, list) for sub in A):
            print(" " * indent + " ".join(str(x) for x in A))
        else:
            for sub in A:
                mat_print(sub, indent=indent + 2)
                print()
    else:
        print(" " * indent + str(A))

        
def generate_random_matrix(shape, min_val=1, max_val=5):
    """
    Generate a random integer matrix with the specified shape.
    
    Args:
        shape (tuple): A tuple (rows, cols) specifying the matrix dimensions
        min_val (int): Minimum value for random integers (default: 1)
        max_val (int): Maximum value for random integers (default: 100)
    
    Returns:
        list: A 2D list representing the matrix
    """
    rows, cols = shape
    matrix = []
    
    for i in range(rows):
        row = []
        for j in range(cols):
            row.append(random.randint(min_val, max_val))
        matrix.append(row)
    
    return matrix
        
        
if __name__ == "__main__":
    # Test matrices
    random.seed(0)
    
    n = 8
    es = 1
    
    rows = 576
    cols = 25
    
    A = generate_random_matrix((rows,cols))
    B = generate_random_matrix((cols,1))
    
    A_posit = list()
    B_posit = list()
    
    for i in A:
        l = list()
        for j in i:
            j_posit = float_to_posit(n,es,j)
            l.append(PCPosit(int(j_posit,2),nbits=n,es=es, mode='bits'))
        A_posit.append(l)
        
    for i in B:
        l = list()
        for j in i:
            j_posit = float_to_posit(n,es,j)
            l.append(PCPosit(int(j_posit,2),nbits=n,es=es, mode='bits'))
        B_posit.append(l)
    
    s = time.time()
    C = matmul(A, B)
    e = time.time()
    print(e-s)
    s = time.time()
    C_posit = matmul_posit(A_posit, B_posit)
    e = time.time()
    print(e-s)