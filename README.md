# CloudSpecter

<img width="1198" height="370" alt="image" src="https://github.com/user-attachments/assets/259303c3-c301-4dc4-b643-aa17b004dbb5" />

CloudSpecter is a multi-cloud bucket reconnaissance and permission testing tool for AWS S3, Google Cloud Storage, and Azure Blob Storage. It detects publicly accessible or misconfigured buckets/containers by safely testing read and write permissions, making it ideal for red team operations and cloud security assessments.

# Usage Examples 

- AWS public bucket<BR>
./cloudspector.sh aws cisrc

- AWS private bucket (with credentials configured)<BR>
./cloudspector.sh aws my-private-bucket

- GCP public bucket<BR>
./cloudspector.sh gcp my-public-gcs-bucket

- GCP private bucket<BR>
./cloudspector.sh gcp my-private-gcs-bucket

- Azure blob container<BR>
./cloudspector.sh azure mycontainer mystorageaccount

High Severity Finding Output:

<img width="1171" height="452" alt="image" src="https://github.com/user-attachments/assets/693c798d-7887-4440-b1e3-e0faab841618" />

Critical Severity Finding Output:

<img width="1120" height="449" alt="image" src="https://github.com/user-attachments/assets/e6abe3b4-9336-48ee-95af-da3afb56be39" />


# Example Output
```
[*] Checking AWS S3 bucket: cisrc
[*] Bucket is readable
[*] Bucket is WRITABLE
Severity Rating: CRITICAL (anonymous write)

[*] Checking GCP GCS bucket: public-bucket
[*] Bucket is readable
[!] Bucket is NOT writable
Severity Rating: HIGH (anonymous read)

[*] Checking Azure Blob container: mycontainer
[*] Container is readable
[!] Container is NOT writable (Azure requires auth)
Severity Rating: LOW (authenticated read)
```
# Severity Rating

| Scenario                                 | Severity        |
| ---------------------------------------- | --------------- |
| Readable + Writable (anonymous/public)   | **CRITICAL**    |
| Readable only (anonymous/public)         | **HIGH**        |
| Readable + Writable (authenticated only) | **MEDIUM**      |
| Readable only (authenticated)            | **LOW**         |
| Not readable                             | **INFO / NONE** |

- CRITICAL: Any bucket/container that allows anonymous write is misconfigured and dangerous.
- HIGH: Public read-only buckets are sensitive (data exposure).
- MEDIUM/LOW: Authenticated access; you can write/read only with credentials.
- INFO/NONE: Private bucket; script cannot read it.

# What CloudSpecter performs on each cloud providers storage account?

| Provider | Read Test | Write Test | Anonymous Write         |
| -------- | --------- | ---------- | ----------------------- |
| AWS      | ✅         | ✅          | ✅                       |
| GCP      | ✅         | ✅          | ✅                       |
| Azure    | ✅         | ✅          | ❌ (platform limitation) |

