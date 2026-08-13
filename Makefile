.PHONY: player-deps player-analyze player-test android ios macos windows publish \
	cloud-up cloud-test nas-agent-test test

player-deps:
	cd apps/player && flutter pub get

player-analyze:
	cd apps/player && dart format --output=none --set-exit-if-changed lib test && flutter analyze

player-test:
	cd apps/player && flutter test

android:
	$(MAKE) -C apps/player android

ios:
	$(MAKE) -C apps/player ios

macos:
	$(MAKE) -C apps/player macos

windows:
	$(MAKE) -C apps/player windows

publish:
	$(MAKE) -C apps/player publish

cloud-up:
	docker compose -f services/cloud/docker-compose.yml up -d --build

cloud-test:
	cd services/cloud && pytest -q

nas-agent-test:
	cd services/nas-agent && pytest -q

test: player-test cloud-test nas-agent-test
