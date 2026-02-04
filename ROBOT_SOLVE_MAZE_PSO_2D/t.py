import numpy as np
min_max = [-5, 5]
number = 50
pop_size = number
n_input = 11
h1 = 8
h2 = 6
n_output = 2
npar = n_input * h1 + h1 + h1 * h2 + h2 + h2 * n_output + n_output
P = np.random.uniform(min_max[0], min_max[1], (pop_size, npar))
print(P)