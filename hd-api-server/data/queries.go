package data

import (
	"context"
	"database/sql"
)

// insert one drive-day
func (repo *DriveStatsRepo) Create(ctx context.Context, driveStats DriveStats) (*DriveStats, error) {
	ctx, cancel := context.WithTimeout(ctx, dbTimeout)
	defer cancel()

	// `returning *` would hand back all 197 columns, smart_* included, and
	// Scan requires one destination per column. Name them instead.
	query := `
		insert into drive_stats (date, serial_number, model, capacity_bytes, failure, datacenter, cluster_id, vault_id, pod_id, pod_slot_num, is_legacy_format)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		returning date, serial_number, model, capacity_bytes, failure, datacenter, cluster_id, vault_id, pod_id, pod_slot_num, is_legacy_format;`

	row := repo.db.QueryRowContext(ctx, query,
		driveStats.Date,
		driveStats.SerialNumber,
		driveStats.Model,
		driveStats.CapacityBytes,
		driveStats.Failure,
		driveStats.Datacenter,
		driveStats.ClusterID,
		driveStats.VaultID,
		driveStats.PodID,
		driveStats.PodSlotNum,
		driveStats.IsLegacyFormat,
	)

	var saved DriveStats
	err := row.Scan(
		&saved.Date,
		&saved.SerialNumber,
		&saved.Model,
		&saved.CapacityBytes,
		&saved.Failure,
		&saved.Datacenter,
		&saved.ClusterID,
		&saved.VaultID,
		&saved.PodID,
		&saved.PodSlotNum,
		&saved.IsLegacyFormat,
	)

	if err != nil {
		return nil, err
	}

	return &saved, nil
}

// serial_number + date is the primary key, so this is always at most one row
func (repo *DriveStatsRepo) GetBySerialAndDate(ctx context.Context, serialNumber string, date string) (*DriveStats, error) {
	ctx, cancel := context.WithTimeout(ctx, dbTimeout)
	defer cancel()

	query := `
		select date, serial_number, model, capacity_bytes, failure, datacenter, cluster_id, vault_id, pod_id, pod_slot_num, is_legacy_format
		from drive_stats
		where serial_number = $1 and date = $2`

	row := repo.db.QueryRowContext(ctx, query, serialNumber, date)

	var one DriveStats
	err := row.Scan(
		&one.Date,
		&one.SerialNumber,
		&one.Model,
		&one.CapacityBytes,
		&one.Failure,
		&one.Datacenter,
		&one.ClusterID,
		&one.VaultID,
		&one.PodID,
		&one.PodSlotNum,
		&one.IsLegacyFormat,
	)

	if err != nil {
		// caller maps sql.ErrNoRows to a 404
		return nil, err
	}

	return &one, nil
}

func (repo *DriveStatsRepo) DeleteRecord(ctx context.Context, serialNumber string, date string) error {
	ctx, cancel := context.WithTimeout(ctx, dbTimeout)
	defer cancel()

	query := `delete from drive_stats where serial_number = $1 and date = $2`

	result, err := repo.db.ExecContext(ctx, query, serialNumber, date)

	if err != nil {
		return err
	}

	// Exec doesn't error on a miss, so check the count ourselves
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (repo *DriveStatsRepo) UpdateRecord(ctx context.Context, payload DriveStats) (*DriveStats, error) {
	ctx, cancel := context.WithTimeout(ctx, dbTimeout)
	defer cancel()

	// Doesnt support partial updates as is.
	query := `
		update drive_stats
		set model = $1, capacity_bytes = $2, failure = $3, datacenter = $4, cluster_id = $5, vault_id = $6, pod_id = $7, pod_slot_num = $8, is_legacy_format = $9
		where serial_number = $10 and date = $11
		returning date, serial_number, model, capacity_bytes, failure, datacenter, cluster_id, vault_id, pod_id, pod_slot_num, is_legacy_format;`

	row := repo.db.QueryRowContext(ctx, query,
		payload.Model,
		payload.CapacityBytes,
		payload.Failure,
		payload.Datacenter,
		payload.ClusterID,
		payload.VaultID,
		payload.PodID,
		payload.PodSlotNum,
		payload.IsLegacyFormat,
		payload.SerialNumber,
		payload.Date,
	)

	var saved DriveStats
	err := row.Scan(
		&saved.Date,
		&saved.SerialNumber,
		&saved.Model,
		&saved.CapacityBytes,
		&saved.Failure,
		&saved.Datacenter,
		&saved.ClusterID,
		&saved.VaultID,
		&saved.PodID,
		&saved.PodSlotNum,
		&saved.IsLegacyFormat,
	)

	if err != nil {
		// an update matching nothing returns no rows
		return nil, err
	}

	return &saved, nil
}

func (repo *RollupRepo) GetAll(ctx context.Context) ([]*Rollup, error) {
	ctx, cancel := context.WithTimeout(ctx, dbTimeout)
	defer cancel()

	query := `
		select model, drive_days, drives, drive_failures, naive_failure_rate, annualized_failure_rate, annualized_failure_rate_pct
		from drive_rollup`

	rows, err := repo.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var aggs []*Rollup

	for rows.Next() {
		var one Rollup
		err := rows.Scan(
			&one.Model,
			&one.DriveDays,
			&one.Drives,
			&one.DriveFailures,
			&one.NaiveFailureRate,
			&one.AnnualizedFailureRate,
			&one.AnnualizedFailureRatePct,
		)
		if err != nil {
			return nil, err
		}
		aggs = append(aggs, &one)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return aggs, nil
}
