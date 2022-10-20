# ZBC Oracle Database

The Zama Blockchain (ZBC) Oracle Database is a key-value database of require statement results plus a signature for them from the oracle. It supports two operations:
* HTTP GET - executed by validators, full nodes or anyone in order to get a signed require result from the DB
* HTTP PUT - only executed by the oracle in order to put a signed require result in the DB

Access control is left to an external HTTP service (e.g. a proxy) that sits in front of the DB. For example, one might allow GET requests from the Internet and only allow PUT request from a local oracle address. Furthermore, TLS handling is also left to the external HTTP service.

Another point is that the intention for the database is to be as simple as possible, without trying to interpret the data it receives/provides. For example, it only expects that the keys are 32 byte hashes and it doesn't impose anything on the signatures. Rationale is that there is external access control such that only the trusted oracle can write to the DB through HTTP PUT.

Currently, the DB doesn't support deletion of require results. That allows any node to catch up to the latest state from any previous point. If that approach proves problematic in terms of DB size and/or performance, we can consider pruning it in a future release.

## API
The DB exposes a REST API on the `/require/<key>` route. The `key` parameter is a hex-encoded byte buffer of 32 bytes (i.e. 64 hex characters).
The DB supports the following methods.

### HTTP PUT
The oracle can put a require result to the DB via an HTTP PUT request with a JSON payload. For example:
```json
{
    "value": true,
    "signature": "YmJiYg=="
}
```
The DB expects two fields:
* `value` - a bool value of the require
* `signature` - a base64-encoded signature

Example request:
```bash
curl -v --header "Content-type: application/json" --request PUT \
  --data '{"value": true, "signature": "YmJiYg=="}' \
  http://127.0.0.1:8001/require/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

### HTTP GET
Validators (or anyone) can get a require value via an HTTP GET request.

Example request:
```bash
curl -v --header "Content-type: application/json" \
    http://127.0.0.1:8001/require/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

The resulting response has the same JSON format as for HTTP PUT:
```json
{
    "value": true,
    "signature": "YmJiYg=="
}
```

## Note on Determinism
It is expected that the oracle generates an unique key for a particular require. For example, the key could be the hash of the require's ciphertext. Based on that, the DB will overwrite a require value for an existing key, expecting that the "new" value is the same as the previous one. That allows the DB to not check the key for existence on every write. Though it is not expected to happen often, it might happen if, for example, the oracle crashes during execution.

## Note on Signature
The DB doesn't impose anything on the signature field other than it being valid base64. It is up to the blockchain protocol to decide what piece of data is signed. For example, one might do `sign(hash(require_ciphertext) || value)`.

## Note on RocksDB
We use RocksDB as an underlying key-value store. We've chosen it, because it is battle-tested, performant, in-process, tweakable and supports concurrent calls from multiple threads. If needed, it can easily be replaced with another store.

## Note on Race Conditions Between Oracle and Non-Oracle Nodes
Since the oracle is the only node that puts require results into the database and since all nodes (oracle and non-oracle ones) execute smart contract code at the same time, there is a race condition between the oracle putting a result and any other node reading it. Currently, the solution to this problem is to poll RocksDB on a GET request, until the result is available. The retry count and the sleep period between retries are configurable - please see more in the [Configuration](#configuration) section.

A more optimal solution could be introduced in a future release.

## Build and Run
```bash
cargo build
cargo run
```

## Configuration
We use the rocket-provided configuration file - [Rocket.toml](Rocket.toml). It supports a number of rocket-specific configuration options as documented here: https://rocket.rs/v0.5-rc/guide/configuration/#configuration

We've introduced the `testing` configuration profile that is only used for integration tests.

The following configuration options are currently supported:

`db_path` - A path to the RocksDB database.

`get_sleep_period_ms` - If a key is non-existent, time to sleep (in ms) before retrying again (applies to GET requests only).

`get_retry_count` - How many times to retry before returning NotFound on GET requests (applies to GET requests only). Set to 0 to turn off retries and make 1 attempt only.

## Testing
Integration tests use a real RocksDB database. The database path is read from the `testing` profile in the configuration (Rocket.toml) file.

In order for tests to run properly, execute them one at a time, using the `testing` profile:
```bash
ROCKET_PROFILE=testing cargo test -- --test-threads=1
```
