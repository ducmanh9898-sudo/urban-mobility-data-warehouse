import json
from urllib.request import Request, urlopen


DISCOVERY_URL = "https://gbfs.citibikenyc.com/gbfs/2.3/gbfs.json"


def fetch_json(url):
    request = Request(
        url,
        headers={"User-Agent": "urban-mobility-data-warehouse/0.1"},
    )

    with urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    discovery = fetch_json(DISCOVERY_URL)

    feeds = {
        feed["name"]: feed["url"]
        for feed in discovery["data"]["en"]["feeds"]
    }

    print("GBFS version:", discovery["version"])

    for name in ("station_information", "station_status"):
        payload = fetch_json(feeds[name])
        stations = payload["data"]["stations"]

        print(f"\nFeed: {name}")
        print("Source last_updated:", payload.get("last_updated"))
        print("Station count:", len(stations))

        if not stations:
            raise ValueError(f"{name} returned no stations")

        print("Sample record:")
        print(json.dumps(stations[0], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()