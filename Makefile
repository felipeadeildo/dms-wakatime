CONFIGPATH ?= $(HOME)/.config/DankMaterialShell

symlink:
	if [ -e "$(HOME)/.config/DankMaterialShell/plugins/dms-wakatime" ]; then rm -f "$(HOME)/.config/DankMaterialShell/plugins/dms-wakatime"; fi
	ln -s "$(PWD)" "$(HOME)/.config/DankMaterialShell/plugins/dms-wakatime"

reload:
	@echo "Reloading DMS plugins..."
	@dms ipc call plugins reload wakaTime
	@echo "Reloaded DMS plugins."

list:
	@echo "DMS Plugins:"
	@dms ipc call plugins list

.PHONY: symlink reload list
