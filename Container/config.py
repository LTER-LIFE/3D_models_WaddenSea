import os

# Digital Ocean configuration
DO_ENDPOINT = "digitaloceanspaces.com"
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_DEFAULT_REGION = "ams3"

BUCKET = "eco-dt-api-data"
PREFIX = "sat_viewer"
DATA_DIR = "./data/"
#DOCKER_DATADIR = os.path.join(DATA_DIR, "sat_viewer_data/")
#RS_RUN = os.path.join(DOCKER_DATADIR, "rs_run/")
#RS_RUN_NEW = os.path.join(DOCKER_DATADIR, "rs_run_new/")

REGIONS = ["Marsdiep", "Vlieland", "Ems", "All"]
YEARS = [2016, 2017, 2019, 2020]
