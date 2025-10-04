# Chat Assistant for Software Defined Infrastructure
This chatbot currently supporting **OpenStack**, can be used in software defined infrastructure such as an OpenStack cloud, Kubernetes to create, delete, list cloud resources by typing commands in plain English as a chat messages to the chat bot. It understands the English and converts into respective OpenStack client commands. 

## What does this Bot solve?
The main idea here to reduce the complexity in using an OpenStack cloud for novices and experts alike. No need to remember all those pesky command line words and the confusing Horizon dashboard. Just chat away your cloud needs to this bot. It will do it for you.

## Installation:

* Clone repo.

  ```
  git clone https://github.com/shank7485/Assistant-for-Software-Defined-Infrastructure.git
  ```

* Edit endpoint.conf to add OpenStack Keystone endpoint IP.

* Create Virtual Environment.	

  ```
  virtualenv venv
  ```

* Source it.
  
  ```
  source venv/bin/activate/
  ```

* Install requirements.txt.	

  ```
  cd Assistant-for-Software-Defined-Infrastructure; pip install -r requirements.txt
  ```

* For deployment, add private key with name `deploy_key.pem` in `/home/ubuntu/` to deploy another OpenStack cloud on another server. The other server should be SSH'able using the `deploy_key.pem`. 

* Run the API server.	

  ```
  python api.py
  ```

* Open the API IP/URL in web brower by going to `http://<IP>:8081` to see a login page. Login with OpenStack credentials.

* Now you have an assistant waiting to recieve your commands. Just chat with it and it will reply back.

## System Diagram
![Diagram](https://raw.githubusercontent.com/shank7485/Assistant-for-Software-Defined-Infrastructure/master/docs/Diagram.png)

## Solidity Hybrid Anchor Registry

This repository also includes a Solidity-based commit-reveal ring buffer anchor registry subsystem for tamper-evident data anchoring with root-only global uniqueness guarantees.

**Features:**
- Commit-reveal pattern with sender binding
- Root-only uniqueness enforcement
- Rolling hash accumulator with domain separation (`DOMAIN = keccak256("ANCHOR_V1")`)
- Optional commit/reveal gating via allowlists
- Merkle proof verification for anchored data
- Gas-optimized with CI-enforced thresholds
- Comprehensive invariant testing

**Documentation:** See [docs/hybrid-anchor-registry.md](docs/hybrid-anchor-registry.md) for full details on architecture, security, and usage.
