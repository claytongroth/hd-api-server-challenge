package main

import (
	"context"
	"database/sql"
	"log"
	"sync"
	"time"

	"hd-api-server/data"
)

// shared application config
type Config struct {
	DB           *sql.DB
	InfoLog      *log.Logger
	ErrorLog     *log.Logger
	Wait         *sync.WaitGroup
	RefreshRate  time.Duration
	Models       data.Models // our models for accessing the database
	cancelRollup context.CancelFunc
}

func (app *Config) RefreshDriveRollup(rollupContext context.Context) {

	// wait until the RefreshRate has passed, then do the rollup refresh
	for {
		select {
		case <-rollupContext.Done():
			app.InfoLog.Println("Stopping drive_rollup refresher")
			return
		// We need to use time.After here because time.Ticker would make them run on top of one another
		case <-time.After(app.RefreshRate):
			// the refresh is a full re-aggregate, so don't pay for it
			// when drive_stats hasn't changed since the last one
			needsRefresh, err := app.Models.Rollup.NeedsRefresh(rollupContext)
			if err != nil {
				app.ErrorLog.Println("drive_rollup refresh check failed:", err)
				continue
			}
			if !needsRefresh {
				app.InfoLog.Println("No drive_stats changes since last refresh, skipping")
				continue
			}

			app.InfoLog.Println("Refreshing drive_rollup")

			start := time.Now()
			err = app.Models.Rollup.RefreshDriveRollup(rollupContext)
			elapsed := time.Since(start).Round(time.Millisecond)

			if err != nil {
				app.ErrorLog.Printf("drive_rollup refresh failed after %s: %v", elapsed, err)
			} else {
				app.InfoLog.Printf("Refreshed drive_rollup in %s", elapsed)
			}
		}
	}
}
