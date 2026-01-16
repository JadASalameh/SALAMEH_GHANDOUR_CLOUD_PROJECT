TF_DIR=terraform
ANSIBLE_DIR=ansible
INVENTORY=$(ANSIBLE_DIR)/inventory.ini

.PHONY: all infra ansible-install ansible-deps inventory frontend-ip ansible-check loadgen stop-loadgen destroy clean


all: infra ansible-install ansible-deps loadgen


infra:
	cd $(TF_DIR) && terraform apply -auto-approve


ansible-install:
	@command -v ansible >/dev/null 2>&1 || \
	  (echo "Installing Ansible..." && sudo apt-get update && sudo apt-get install -y ansible)

ansible-deps:
	ansible-galaxy collection list | grep -q '^community.docker' || \
	  (echo "Installing Ansible collection: community.docker" && ansible-galaxy collection install community.docker)


inventory: infra
	@VM_IP=$$(cd $(TF_DIR) && terraform output -raw loadgen_external_ip | tr -d '\r\n'); \
	echo "[loadgen]" > $(INVENTORY); \
	echo "$$VM_IP ansible_user=ansible ansible_ssh_private_key_file=$$HOME/.ssh/ansible_vm" >> $(INVENTORY)


ansible-check: inventory ansible-install ansible-deps
	@echo "Waiting for SSH to become available..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
	  if (cd $(ANSIBLE_DIR) && ansible loadgen -m ping >/dev/null 2>&1); then \
	    echo "SSH is ready"; \
	    echo "Running final connectivity check:"; \
	    (cd $(ANSIBLE_DIR) && ansible loadgen -m ping); \
	    exit 0; \
	  fi; \
	  sleep 10; \
	done; \
	echo "ERROR: SSH did not become ready in time"; \
	exit 1



frontend-ip:
	kubectl get svc frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'


loadgen: ansible-check
	@FRONTEND_IP=$$(make -s frontend-ip); \
	if [ -z "$$FRONTEND_IP" ]; then \
	  echo "ERROR: frontend external IP not found. Is the frontend-external Service ready?"; \
	  exit 1; \
	fi; \
	echo "Using frontend IP: $$FRONTEND_IP"; \
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --extra-vars "frontend_ip=$$FRONTEND_IP"


stop-loadgen: inventory
	cd $(ANSIBLE_DIR) && ansible-playbook stop-loadgen.yml

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve


clean:
	rm -f $(INVENTORY)

