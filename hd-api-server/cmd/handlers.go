package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"hd-api-server/data"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
)

// small json response struct
type jsonResponse struct {
	Error   bool   `json:"error"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

func (app *Config) HelloWorldHandler(w http.ResponseWriter, r *http.Request) {
	app.InfoLog.Println("Hit HelloWorld Handler")

	// example JSON response
	payload := jsonResponse{
		Error:   false,
		Message: "Hello World",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(payload); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}

func (app *Config) CreateDriveStatsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	app.InfoLog.Println("Hit CreateDriveStatsHandler Handler")

	// read the JSON body into a DriveStats
	var payload data.DriveStats
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		app.ErrorLog.Println(err)
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	newDrive, err := app.Models.DriveStats.Create(r.Context(), payload)

	if err != nil {
		app.ErrorLog.Println(err)

		http.Error(w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)

	app.InfoLog.Println("Finished in", time.Since(start))
	if err := json.NewEncoder(w).Encode(newDrive); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}

func (app *Config) ReadRollupStatsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	app.InfoLog.Println("Hit ReadRollupStatsHandler Handler")

	rollUp, err := app.Models.Rollup.GetAll(r.Context())

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "no records found", http.StatusNotFound)
			return
		}
		app.ErrorLog.Println(err)

		http.Error(w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	app.InfoLog.Println("Finished in", time.Since(start))
	if err := json.NewEncoder(w).Encode(rollUp); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}

func (app *Config) ReadDriveStatsBySerialAndDateHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	app.InfoLog.Println("Hit ReadDriveStatsBySerialAndDateHandler Handler")

	// Read the url params into serial_number and date
	serialNumber := chi.URLParam(r, "serial_number")
	date := chi.URLParam(r, "date")

	app.InfoLog.Println("serial_number:", serialNumber, "date:", date)

	// Handle if params are not there.
	if serialNumber == "" || date == "" {
		http.Error(w, "invalid serial_number or date", http.StatusBadRequest)
		return
	}

	rollUp, err := app.Models.DriveStats.GetBySerialAndDate(r.Context(), serialNumber, date)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "no records found", http.StatusNotFound)
			return
		}
		app.ErrorLog.Println(err)

		http.Error(w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	app.InfoLog.Println("Finished in", time.Since(start))
	if err := json.NewEncoder(w).Encode(rollUp); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}

func (app *Config) UpdateDriveStatsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	app.InfoLog.Println("Hit UpdateDriveStatsHandler Handler")

	var payload data.DriveStats
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		app.ErrorLog.Println(err)
		http.Error(w, "invalid JSON body", http.StatusBadRequest)
		return
	}

	updatedDrive, err := app.Models.DriveStats.UpdateRecord(r.Context(), payload)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "no records found", http.StatusNotFound)
			return
		}
		app.ErrorLog.Println(err)

		http.Error(w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	app.InfoLog.Println("Finished in", time.Since(start))
	if err := json.NewEncoder(w).Encode(updatedDrive); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}

func (app *Config) DeleteDriveStatsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	app.InfoLog.Println("Hit DeleteDriveStatsHandler Handler")

	// Read the url params into model and date
	serialNumber := chi.URLParam(r, "serial_number")
	date := chi.URLParam(r, "date")

	if serialNumber == "" || date == "" {
		http.Error(w, "invalid model or date", http.StatusBadRequest)
		return
	}

	err := app.Models.DriveStats.DeleteRecord(r.Context(), serialNumber, date)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "no records found", http.StatusNotFound)
			return
		}
		app.ErrorLog.Println(err)

		http.Error(w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	app.InfoLog.Println("Finished in", time.Since(start))
	resp := jsonResponse{
		Error:   false,
		Message: "drive-day deleted",
	}
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		app.ErrorLog.Println("encoding response:", err)
	}
}
