# Triple-Packed POSIT MAC

## Folder Structure

```
.
├── src/        # SystemVerilog source files (design)
├── tb/         # SystemVerilog testbenches
└── Python Inference Files/     # Software simulation using sgposit library
```

### Description

* **`src/`**: Contains the RTL modules implementing posit arithmetic operations.
* **`tb/`**: Includes testbenches for verifying the RTL modules.
* **`Python Inference Files/`**: Python scripts using the [`sgposit`](https://pypi.org/project/sgposit/) library for simulating and validating posit arithmetic in software.

## Requirements

* **SystemVerilog simulator** (e.g., Vivado)
* **Python 3.x**
* Install Python dependencies:

  ```bash
  pip install sgposit
  ```

## License

This project is released under the MIT License.
