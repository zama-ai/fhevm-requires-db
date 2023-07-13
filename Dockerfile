FROM rust:buster as builder
RUN apt-get update && apt-get install -y clang

WORKDIR /usr/local/app
ADD . .
RUN cargo build --release 

FROM debian:bullseye-slim
WORKDIR /usr/local/app
RUN apt-get update && apt-get install -y clang
RUN apt-get install libc6 -y
COPY --from=builder /usr/local/app/target/release/fhevm-requires-db .
COPY --from=builder /usr/local/app/Rocket.toml .

CMD ["/usr/local/app/fhevm-requires-db"]
