package data

import (
	"database/sql"
	"time"
)

const dbTimeout = time.Second * 3

// When this is called, the db is already connected,
// So this way the Repos share the same pool
func New(db *sql.DB) Models {
	return Models{
		DriveStats: DriveStatsRepo{db: db},
		Rollup:     RollupRepo{db: db},
	}
}

// Models is the set of repositories handlers reach through.
type Models struct {
	DriveStats DriveStatsRepo
	Rollup     RollupRepo
}

// repositories own the connection pool
type DriveStatsRepo struct{ db *sql.DB }

// These are here for the query methods to use
type RollupRepo struct{ db *sql.DB }

// records

// DriveStats is one drive-day row out of drive_stats.
type DriveStats struct {
	Date           time.Time `json:"date"`
	SerialNumber   string    `json:"serial_number"`
	Model          string    `json:"model"`
	CapacityBytes  int64     `json:"capacity_bytes"` // bigint; -1 means unknown
	Failure        int16     `json:"failure"`        // smallint, 0 or 1
	Datacenter     *string   `json:"datacenter,omitempty"`
	ClusterID      *string   `json:"cluster_id,omitempty"`
	VaultID        *string   `json:"vault_id,omitempty"`
	PodID          *string   `json:"pod_id,omitempty"`
	PodSlotNum     *string   `json:"pod_slot_num,omitempty"`
	IsLegacyFormat *bool     `json:"is_legacy_format,omitempty"`
}

// Rollup is one row from the drive_stats_rollup
type Rollup struct {
	Model                    string  `json:"model"`
	DriveDays                int64   `json:"drive_days"`
	Drives                   int64   `json:"drives"`
	DriveFailures            int64   `json:"drive_failures"`
	NaiveFailureRate         float64 `json:"naive_failure_rate"`
	AnnualizedFailureRate    float64 `json:"annualized_failure_rate"`
	AnnualizedFailureRatePct float64 `json:"annualized_failure_rate_pct"`
}
