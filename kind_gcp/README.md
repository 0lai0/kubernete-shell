# kubernete-shell
#### Overview
This shell script sets up a Kubernetes Master node on a physical machine running Ubuntu 22.04 LTS. It installs all required dependencies, configures the system, and initializes a Kubernetes cluster.

#### How to Use
1. **Download the Script**
   - Save the script 

2. **Make it Executable**
   - Run this command:
     ```
     chmod +x kind_setup.sh
     ```

3. **Run the Script**
   - Execute it with `sudo`:
     ```
     sudo ./kind_setup.sh
     ```
   - Follow the prompts to confirm or enter the Master node IP.

4. **build kind cluster**
  - use command:
    ```
    sudo kind create cluster --name my-cluster
    ```
  - use yaml:
    ```
    vim kind-cluster.yaml
    ```
    ```
    sudo kind create cluster --config kind-config.yaml
    ```

5. **Check the Results**
   - After completion, check the cluster status:
     ```
     kind get clusters
     ```
   - delete cluster:
     ```
     kind delete --name cluster-name
     ```

#### Troubleshooting
- If the IP detection fails, manually enter the correct IP when prompted.
- For hardware errors, ensure your machine meets the minimum requirements.

---
