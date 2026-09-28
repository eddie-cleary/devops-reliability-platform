from fastapi import FastAPI
from fastapi.responses import JSONResponse
import random
import time

app = FastAPI()


@app.get("/healthy")
def healthy():
    return {"status": "ok"}


@app.get("/error")
def error():
    return JSONResponse(
        status_code=500,
        content={"status": "error"}
    )


@app.get("/slow")
def slow():
    time.sleep(5)
    return {"status": "slow"}


@app.get("/flaky")
def flaky():
    if random.choice([True, False]):
        return {"status": "ok"}

    return JSONResponse(
        status_code=500,
        content={"status": "error"}
    )