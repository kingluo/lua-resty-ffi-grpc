NGINX_BIN ?= /opt/resty_ffi/nginx/sbin/nginx

.PHONY: build
build:
	cd grpc_client; cargo build --release

.PHONY: run
run:
	@cd demo; bash -c '[[ -d logs ]] || mkdir logs'
	cd demo; LD_LIBRARY_PATH=$(PWD)/grpc_client/target/release:/usr/local/lib/lua/5.1 $(NGINX_BIN) -p $(PWD)/demo -c nginx.conf

.PHONY: test
test:
	curl localhost:20000/echo
	curl localhost:20000/get_feature
	curl localhost:20000/list_features
	curl localhost:20000/record_route
	curl localhost:20000/route_chat
