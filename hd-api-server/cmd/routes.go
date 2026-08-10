package main

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func (app *Config) routes() http.Handler {
	mux := chi.NewRouter()

	mux.Use(middleware.Recoverer)

	mux.Get("/helloworld", app.HelloWorldHandler)

	// CREATE
	/*
		"date" must be RFC 3339 -- data.DriveStats.Date is a time.Time, and
		time.Time.UnmarshalJSON rejects a bare "2025-10-01".

		curl -X POST http://localhost:8080/drive_stats \
		-H "Content-Type: application/json" \
		-d '{
				"date": "2025-10-01T00:00:00Z",
				"serial_number": "456456456",
				"model": "FAKEMODEL2",
				"capacity_bytes": -1,
				"failure": 0,
				"datacenter": "DC1",
				"cluster_id": "CL1",
				"vault_id": "VA1",
				"pod_id": "POD1",
				"pod_slot_num": "SLOT1",
				"is_legacy_format": false
			}'

	*/
	mux.Post("/drive_stats", app.CreateDriveStatsHandler)

	// READ

	/*
		curl -X GET http://localhost:8080/rollup_stats | jq
	*/
	mux.Get("/rollup_stats", app.ReadRollupStatsHandler)

	/*
		curl -X GET http://localhost:8080/drive_stats/CT250MX500SSD1/2025-10-06 | jq
	*/
	mux.Get("/drive_stats/{model}/{date}", app.ReadDriveStatsByModelAndDateHandler)

	// UPDATE (PROBLEMS: we shouldnt be able to change serial number or date)
	// PROBLEM: we cant update the date unless the format is exactly 2025-10-01T15:04:05Z
	/*
		curl -X PUT http://localhost:8080/drive_stats -H "Content-Type: application/json" -d '{"serial_number":"456456456","date":"2025-10-01T15:04:05Z","model":"FAKEMODEL3","capacity_bytes":-1,"failure":0,"datacenter":"DC1","cluster_id":"CL1","vault_id":"VA1","pod_id":"POD1","pod_slot_num":"SLOT1","is_legacy_format":false}'
	*/
	mux.Put("/drive_stats", app.UpdateDriveStatsHandler)

	// DELETE
	/*
		curl -X DELETE http://localhost:8080/drive_stats/456456456/2025-10-01
	*/
	mux.Delete("/drive_stats/{serial_number}/{date}", app.DeleteDriveStatsHandler)

	return mux
}
