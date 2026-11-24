ANSIBLE_DIR := ansible

# Подготовка сервера: установка Docker + деплой приложения
deploy:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini deploy.yml

# Проверка ping (что Ansible видит сервер)
ping:
	cd $(ANSIBLE_DIR) && ansible webservers -i inventory.ini -m ping

# Статус контейнера на сервере
status:
	ssh golovinmd@130.193.58.173 "docker ps"

# Логи приложения
logs:
	ssh golovinmd@130.193.58.173 "docker logs bulletins-container --tail 100"

# Health-check
health:
	curl -s http://130.193.58.173:9090/actuator/health
