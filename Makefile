.PHONY: deploy.envsh

SSH_CONFIG := ./ssh_config

USERNAME := isucon
ALL_HOST_IPADDRESSES := xx.xx.xx.xx yy.yy.yy.yy zz.zz.zz.zz
ALL_HOSTS := isu1 # isu2 isu3
WEB := isu1 # isu2 isu3
DB  := isu1 # isu2 isu3
APP_MAIN_SERVERS := isu1 # isu2 isu3

REMOTE_GIT_DIR := /home/isucon/git

NGINX_LOG := /var/log/nginx/access.log

SSH := ssh -F $(SSH_CONFIG)
SCP := scp -F $(SSH_CONFIG)
RSYNC := rsync -e "$(SSH)" -av --delete --force --omit-dir-times

ALP_OPTION := --sort=sum -r -m '/api/isu/\w+,/isu/\w+,/api/condition/\w+' -o count,2xx,3xx,4xx,5xx,method,uri,min,max,sum,avg

space := $(subst ,, )
comma := ,

.DEFAULT_GOAL := help

define exec-command
$(SSH) $(1) "$(2)";
endef

define update-git
$(SSH) $(1) "cd ${REMOTE_GIT_DIR}; git pull";
endef

define daemon-reload
$(SSH) $(1) "sudo systemctl daemon-reload";
endef

define logrotate-nginx
$(SSH) $(1) "sudo chmod 644 $(NGINX_LOG)";
$(SSH) $(1) "sudo mv $(NGINX_LOG) $(NGINX_LOG).lotated";
$(SSH) $(1) "sudo systemctl reload nginx";
endef

define restart-nginx
$(SSH) $(1) "sudo systemctl restart nginx";
endef

define update-app
$(SSH) $(1) "cd /home/isucon/webapp/ruby && /home/isucon/local/ruby/bin/bundle install";
$(SSH) $(1) "sudo systemctl restart isucondition.ruby";
endef

define restart-db
$(SSH) $(1) "sudo systemctl restart mariadb";
endef

define restart-mock
$(SSH) $(1) "sudo systemctl restart jiaapi-mock.service";
endef

define notify-slack
echo $(1)
endef

local.configure: ## Configure local machine.(e.g. ssh_config)
	sh utility/generate_ssh_config.sh $(USERNAME) $(subst $(space),$(comma),$(ALL_HOST_IPADDRESSES)) > $(SSH_CONFIG)

notify-score:
	echo "スコア $(SCORE) / $$(git rev-parse HEAD)" |  ./utility/notify_slack-$(shell uname -s) -c ./utility/notify_slack.toml

alp: ## Exec alp
	@$(foreach host, $(WEB), echo \#\# $(host); cat ./tmp/nginx.$(host).log | alp ltsv $(ALP_OPTION))

alp.log-rotate: ## logrotate nginx on remote host
	$(foreach host, $(WEB),$(call logrotate-nginx,$(host)))
	$(call notify-slack,Executed: rotate Nginx access.log )

alp.log-download: ## download Nginx log
	$(foreach host, $(WEB),$(shell $(SCP) $(host):$(NGINX_LOG) ./tmp/nginx.$(host).log))

deploy.envsh: ## deploy env.sh
	$(foreach host, $(ALL_HOSTS),$(call update-git,$(host)))
	$(foreach host, $(ALL_HOSTS),$(call exec-command,$(host), cp ${REMOTE_GIT_DIR}/infra/home/isucon/env.sh.$(host) ~/env.sh))

deploy.nginx: ## deploy nginx config
	$(foreach host, $(WEB),$(call update-git,$(host)))
	$(foreach host, $(WEB),$(call exec-command,$(host), find ${REMOTE_GIT_DIR}/infra/etc/nginx -type f -exec sh -c 'sudo cp {} \$$(echo {} | sed -e s_${REMOTE_GIT_DIR}/infra__)' \;))
	$(foreach host, $(WEB),$(call restart-nginx,$(host)))
	$(call notify-slack,Executed: Update Nginx config )

deploy.mysql: ## deploy mysql config
	$(foreach host, $(DB),$(call update-git,$(host)))
	$(foreach host, $(DB),$(call exec-command,$(host), find ${REMOTE_GIT_DIR}/infra/etc/mysql -type f -exec sh -c 'sudo cp {} \$$(echo {} | sed -e s_${REMOTE_GIT_DIR}/infra__)' \;))
	$(foreach host, $(DB), $(call restart-db,$(host)))
	$(call notify-slack,Executed: Update mysql config )

help: ## Self-documented Makefile
	@grep -E '^([a-zA-Z_-]|\.)+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'