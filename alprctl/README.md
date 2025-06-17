# alprctl – ALPR System Control Utility

`alprctl` is a lightweight command-line utility used to communicate with the running ALPR service over a UNIX socket. It allows users to send runtime commands to the daemon in a safe and structured manner.

---

## 📦 Features

- ✅ Start the ALPR daemon safely with `alprctl start`
- 🔌 Send runtime commands to the daemon over a UNIX domain socket
- 🧪 Validates service availability before communication
- 🧾 Simple, single-file C++ utility

---

## 🧠 How It Works

- **Start Command**:
  - Checks if the daemon is already running using the UNIX socket path (`ALPR_SOCKET_PATH`)
  - If not running, it launches the service using `systemctl start alpr_system.service`
  - Waits up to 5 seconds (50 × 100ms) for the daemon to come online

- **Other Commands**:
  - Opens a socket connection to the daemon
  - Sends the command as a plain string
  - Waits for a response and prints it to `stdout`

---