# Enterprise environments

Terraform component roots are grouped by their existing environment:

```text
enterprise/
├── common/
├── dev/
├── prod/
│   ├── alb/
│   └── vpc/
└── staging/
    ├── ec2/
    └── s3/
```

Each component directory remains an independent Terraform run and state. The
files only call the existing modules under `modules/v1`; this reorganization
does not add or change a Terraform module.

Shared values remain in `enterprise/common/config.json`.
