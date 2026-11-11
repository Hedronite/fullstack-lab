variable "region" {
  description = "Region for the ledger buckets."
  type        = string
  default     = "us-east-1"
}

variable "shards" {
  description = "Ledger shard suffixes. One bucket per shard: hx-lab14-<shard>."
  type        = set(string)
  # TODO(task 1): the real account holds three shard buckets (a, b and c); this list stops at b.
  default = ["a", "b"]
}
