ANSIBLE_DIR := ansible
SERVER := golovinmd@130.193.58.173

deploy:
	cd $(ANSIBLE_DIR) && set -a && . ./.env && ansible-playbook -i inventory.ini deploy.yml

ping:
	cd $(ANSIBLE_DIR) && set -a && . ./.env && ansible webservers -i inventory.ini -m ping

status:
	ssh $(SERVER) "docker ps"

logs:
	ssh $(SERVER) "docker logs bulletins-container --tail 100"

health:
	cd $(ANSIBLE_DIR) && set -a && . ./.env && curl -s -u $${METRICS_USER:-admin}:$${METRICS_PASSWORD} http://130.193.58.173/actuator/health

metrics:
	cd $(ANSIBLE_DIR) && set -a && . ./.env && curl -s -u $${METRICS_USER:-admin}:$${METRICS_PASSWORD} http://130.193.58.173/actuator/prometheus | head -20

node-metrics:
	ssh $(SERVER) "curl -s http://localhost:9100/metrics | head -20"

monitoring:
	cd $(ANSIBLE_DIR) && set -a && . ./.env && ansible-playbook -i inventory.ini monitoring.yml


