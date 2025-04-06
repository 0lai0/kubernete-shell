# kubernete-shell
#### Overview
This shell script sets up a Kubernetes Master node on a physical machine running Ubuntu 22.04 LTS. It installs all required dependencies, configures the system, and initializes a Kubernetes cluster.

#### How to Use
1. **Download the Script**
   - Save the script 

2. **Make it Executable**
   - Run this command:
     ```
     chmod +x gcp_k8s_master.sh
     ```

3. **Run the Script**
   - Execute it with `sudo`:
     ```
     sudo ./gcp_k8s_master.sh
     ```
   - Follow the prompts to confirm or enter the Master node IP.

4. **Check the Results**
   - After completion, check the cluster status:
     ```
     kubectl get nodes
     ```
   - View the log file if there are issues:
     ```
     cat kubeadm_init.log
     ```
   - Find the Worker node join command:
     ```
     cat k8s-join-command.txt
     ```

#### Output Files
- `kubeadm_init.log`: Log of the Kubernetes initialization process.
- `k8s-join-command.txt`: Command to join Worker nodes to the cluster.

#### Customization
- **Kubernetes Version**: Edit `K8S_VERSION` in the script (e.g., `1.29.2-1.1`).
- **Pod Network**: Change `POD_CIDR` if needed (default is `10.244.0.0/16`).

#### Troubleshooting
- If the IP detection fails, manually enter the correct IP when prompted.
- For hardware errors, ensure your machine meets the minimum requirements.

---
