variable "region" {
  description = "Region for the ledger buckets."
  type        = string
  default     = "us-east-1"
}

variable "shards" {
  description = "Ledger shard suffixes. One bucket per shard: hx-lab14-<shard>."
  type        = set(string)
  default = ["a", "b", "c"]
}
