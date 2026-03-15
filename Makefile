CONFIGPATH ?= $(HOME)/.config/DankMaterialShell

symlink:

	@rm -f "$(CONFIGPATH)/plugins/dms-wakatime"
	@ln -s "$(PWD)" "$(CONFIGPATH)/plugins/dms-wakatime"

reload:
	@echo "Reloading DMS plugins..."
	@dms ipc call plugins reload wakaTime
	@echo "Reloaded DMS plugins."

list:
	@echo "DMS Plugins:"
	@dms ipc call plugins list

.PHONY: symlink reload list
