use rocket::serde::json::Json;
use rocket::State;

use memory::{RankedState, ZAddRequest, ZIncrByPeriodRequest, ZIncrByRequest, ZRangeRequest};

mod memory;

#[macro_use]
extern crate rocket;

#[post("/zadd/<table>", data = "<request>")]
async fn zadd(state: &State<RankedState>, table: String, request: Json<ZAddRequest>) -> String {
    state.zadd(table, request.into_inner())
}

#[post("/zincrby/<table>", data = "<request>")]
async fn zincrby(
    state: &State<RankedState>,
    table: String,
    request: Json<ZIncrByRequest>,
) -> String {
    state.zincrby(table, request.into_inner())
}

#[post("/zincrbyp/<table>", data = "<request>")]
async fn zincrbyp(
    state: &State<RankedState>,
    table: String,
    request: Json<ZIncrByPeriodRequest>,
) -> String {
    state.zincrbyp(table, request.into_inner())
}

#[post("/zrange/<table>", data = "<request>")]
async fn zrange(state: &State<RankedState>, table: String, request: Json<ZRangeRequest>) -> String {
    state.zrange(table, request.into_inner())
}

#[post("/zrevrange/<table>", data = "<request>")]
async fn zrevrange(
    state: &State<RankedState>,
    table: String,
    request: Json<ZRangeRequest>,
) -> String {
    state.zrevrange(table, request.into_inner())
}

#[post("/flushall")]
async fn flushall(state: &State<RankedState>) -> String {
    state.flushall()
}

#[launch]
fn rocket() -> _ {
    rocket::build()
        .manage(RankedState::new("pages".to_string()))
        .mount(
            "/",
            routes![zadd, zincrby, zincrbyp, zrange, zrevrange, flushall],
        )
}
