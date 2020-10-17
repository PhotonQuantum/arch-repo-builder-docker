import oss2
import os
import mimetypes

endpoint = os.environ["ENDPOINT"]
auth = oss2.Auth(os.environ["APIKEY"], os.environ["APISECRET"])

def main():
    bucket = oss2.Bucket(auth, endpoint, os.environ["BUCKET"])
    for obj in oss2.ObjectIterator(bucket):
        if not obj.size == 0:
            mime, _ = mimetypes.guess_type(obj.key)
            if mime:
                print(f"{obj.key} - {mime}")
                meta = bucket.head_object(obj.key).headers
                meta = {k:v for k, v in meta.items() if k.startswith("x-oss-meta")}
                meta["Content-Type"] = mime
                bucket.update_object_meta(obj.key, meta)

main()