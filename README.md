# AES-128-Encryption-IP-with-AXI4-Lite-Interface
Implemented a AES-128 10 stage pipelined IP AXI-4 Lite interface for interfacing with memory and CPU ,it fetches the plain text and writes the encrypted cipher text back to the slave memory without any CPU intervention and stalls.

---

## Key Design Features

- **Dual State Machines**  
  Separate read and write FSMs ensure reliable AXI handshakes with overlapping channels to reduce communication stalls in the design

- **AXI-Lite Protocol**  
  Fully compliant handshaking: AR, R, AW, W, and B channels.

- **Byte Address Conversion**  
  AXI uses byte addressing; this design converts word-based addresses accordingly.

- **Dynamic Key update mode**  
  Implemented On-the-Fly Key expansion in the pipeline to support dynamic key update mode

- **Status and control registers**  
  Implemented control registers for the CPU to write control signals to the IP and status register to see the status of the IP from the CPU.

---
## Architecture Overview
![AES_IP](Block_diagram.png)

---
## State Machine Overview

### Read FSM

| State       | Description |
|-------------|-------------|
| `IDLE` | Waits for start |
| `READ` | reads 4 32 bit data and packs it into 128 bit plain text through channel overlap. |
| `WAIT` | if !AES_ready it waits for the pipeline, it is for backpressure handling |

![Read State Machine](Read_FSM.png)

### Write FSM

| State       | Description |
|-------------|-------------|
| `IDLE` | Waits for aes_done |
| `WRITE` | writes the 128 bit cipher in 4 32 bit stream using channel overlap. |
| `WAIT` | if the next cipher text isn't ready it waits for the pipeline, it is for backpressure handling |

![Write State Machine](write_FSM.png)

---

## Memory Mapped I/O architecture

We are using memory mapped I/O to communicate with the IP using a unique address to communicate with the IP which is accessed by CPU on a shared bus conveniently.

## Testing

Successfully verified the pipeline by Stress testing the AES Pipeline with 500 AES vectors with dynamic key updates through test bench by AXI-4 Lite







