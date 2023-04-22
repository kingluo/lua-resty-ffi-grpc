# lua-resty-ffi-grpc

openresty grpc client library based on rust [tonic](https://github.com/hyperium/tonic).

**It works for all versions of openresty, and it's a non-intrusive library without need to re-compile openresty.**

## Background

http://luajit.io/posts/implement-grpc-client-in-rust-for-openresty/

[GRPC](https://en.wikipedia.org/wiki/GRPC) is an important RPC protocol, especially for k8s (cloud native env).

But OpenResty does not have a GRPC client library, especially in non-intrusive way
(i.e. do not require re-compile the openresty due to C module implementation).

> tonic is a gRPC over HTTP/2 implementation focused on high performance, interoperability, and flexibility. This library was created to have first class support of async/await and to act as a core building block for production systems written in Rust.

Why not encapsulate tonic so that we could reuse it in openresty?

[lua-resty-ffi](https://github.com/kingluo/lua-resty-ffi) provides an efficient and generic API to do hybrid programming
in openresty with mainstream languages (Go, Python, Java, Rust, Nodejs).

**lua-resty-ffi-grpc = lua-resty-ffi + tonic**

## Synopsis

```lua
local grpc = require("resty.ffi.grpc")

grpc.loadfile("helloworld.proto")
grpc.loadfile("route_guide.proto")
grpc.loadfile("echo.proto")

--
-- unary call
--
local ok, conn = grpc.connect("[::1]:50051")
local ok, res = conn:unary(
    "/helloworld.Greeter/SayHello",
    {name = "foobar"}
)
assert(ok)
assert(res.message == "Hello foobar!")

--
-- tls/mtls enabled unary call
--
local ok, conn = grpc.connect("[::1]:50051",
    {
        host = "example.com",
        ca = grpc.readfile("/opt/tonic/examples/data/tls/ca.pem"),
        cert = grpc.readfile("/opt/tonic/examples/data/tls/client1.pem"),
        priv_key = grpc.readfile("/opt/tonic/examples/data/tls/client1.key"),
    }
)
assert(ok)

local ok, res = conn:unary(
    "/grpc.examples.echo.Echo/UnaryEcho",
    {message = "hello"}
)
assert(ok)
assert(res.message == "hello")

--
-- A server-to-client streaming RPC.
--
local ok, stream = conn:new_stream("/routeguide.RouteGuide/ListFeatures")
assert(ok)

local rectangle = {
    lo = {latitude = 400000000, longitude = -750000000},
    hi = {latitude = 420000000, longitude = -730000000},
}
local ok = stream:send(rectangle)
assert(ok)

local ok = stream:close_send()
assert(ok)

while true do
    local ok, res = stream:recv()
    assert(ok)
    if not res then
        break
    end
    ngx.say(cjson.encode(res))
end

--
-- A client-to-server streaming RPC.
--
local ok, stream = conn:new_stream("/routeguide.RouteGuide/RecordRoute")
assert(ok)

for i=1,3 do
    local point = {latitude = 409146138 + i*100, longitude = -746188906 + i*50}
    local ok = stream:send(point)
    assert(ok)
end

local ok = stream:close_send()
assert(ok)

local ok, res = stream:recv()
assert(ok)
ngx.say(cjson.encode(res))

local ok, res = stream:recv()
assert(ok and not res)

local ok = stream:close()
assert(ok)

local ok = conn:close()
assert(ok)

--
-- A Bidirectional streaming RPC.
--
local ok, stream = conn:new_stream("/routeguide.RouteGuide/RouteChat")
assert(ok)

for i=1,3 do
    local note = {
        location = {latitude = 409146138 + i*100, longitude = -746188906 + i*50},
        message = string.format("note-%d", i),
    }
    local ok = stream:send(note)
    assert(ok)

    local ok, res = stream:recv()
    assert(ok)
    ngx.say(cjson.encode(res))
end

local ok = stream:close()
assert(ok)

local ok = conn:close()
assert(ok)
```

## Demo

```bash
# prepare the toolchain
# refer to https://github.com/kingluo/lua-resty-ffi/blob/main/build.sh
# for centos7
source scl_source enable devtoolset-9
# for centos8
source /opt/rh/gcc-toolset-9/enable
# for ubuntu or debian
apt install build-essential

# install lua-resty-ffi
# https://github.com/kingluo/lua-resty-ffi#install-lua-resty-ffi-via-luarocks
# set `OR_SRC` to your openresty source path
luarocks config variables.OR_SRC /tmp/tmp.Z2UhJbO1Si/openresty-1.21.4.1
luarocks install lua-resty-ffi

# Install protoc-3 if not yet
# https://grpc.io/docs/protoc-installation/
PB_REL="https://github.com/protocolbuffers/protobuf/releases"
curl -LO $PB_REL/download/v3.15.8/protoc-3.15.8-linux-x86_64.zip
unzip protoc-3.15.8-linux-x86_64.zip -d /usr/local

# install lua-protobuf
luarocks install lua-protobuf

# install rust if not yet
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

cd /opt
git clone https://github.com/kingluo/lua-resty-ffi-grpc

# build libgrpc_client.so
cd /opt/lua-resty-ffi-grpc/grpc_client
cargo build --release

# run nginx
cd /opt/lua-resty-ffi-grpc/demo
mkdir logs
LD_LIBRARY_PATH=/opt/lua-resty-ffi-grpc/grpc_client/target/release:/usr/local/lib/lua/5.1 \
nginx -p $PWD -c nginx.conf

# run tonic helloworld-server
cd /opt
git clone https://github.com/hyperium/tonic
cd /opt/tonic
cargo run --release --bin helloworld-server

# hello world
curl localhost:20000/say_hello
ok

# run tonic tls-client-auth-server
cd /opt/tonic
cargo run --release --bin tls-client-auth-server

# mtls
curl localhost:20000/tls
ok
```
