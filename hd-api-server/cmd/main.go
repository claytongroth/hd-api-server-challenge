package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v4/stdlib"

	"hd-api-server/data"
)

func main() {
	db := initDB()

	infoLog := log.New(os.Stdout, "INFO: \t ", log.Ldate|log.Ltime)
	errLog := log.New(os.Stdout, "Error: \t ", log.Ldate|log.Ltime|log.Lshortfile)

	wg := sync.WaitGroup{}

	app := Config{
		DB:       db,
		InfoLog:  infoLog,
		ErrorLog: errLog,
		Wait:     &wg,
		Models:   data.New(db),
	}

	// go routine for doing the `REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;`
	rollupContext, cancelRollup := context.WithCancel(context.Background())
	app.cancelRollup = cancelRollup
	app.RefreshRate = 10 * time.Minute
	wg.Add(1)
	go func() {
		defer wg.Done()
		app.InfoLog.Println("Starting drive_rollup refresher")
		app.RefreshDriveRollup(rollupContext)
	}()

	go app.ListenForShutdown()

	app.serve()
}

func (app *Config) serve() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:    fmt.Sprintf(":%s", port),
		Handler: app.routes(),
	}

	app.InfoLog.Println("Starting web server on port", port)

	err := srv.ListenAndServe()
	if err != nil {
		log.Panic(err)
	}
}

func connectToDB() *sql.DB {
	counts := 0

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		// local `go run` outside compose
		dsn = "postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable"
	}

	for {
		connection, err := openDB(dsn)
		if err != nil {
			log.Println("Unable to connect to DB:", err)
		} else {
			log.Println("Connected to the DB!")
			return connection
		}
		if counts > 10 {
			log.Panic("Unable to connect to DB")
			return nil
		}
		log.Println("Backing off for one second")
		time.Sleep(1 * time.Second)
		counts++
	}
}

func openDB(dsn string) (*sql.DB, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}

	err = db.Ping()
	if err != nil {
		return nil, err
	}

	return db, nil
}

func initDB() *sql.DB {
	conn := connectToDB()
	if conn == nil {
		log.Panic("unable to connect to DB")
	}

	return conn
}

func (app *Config) ListenForShutdown() {
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	app.shutdown()
	os.Exit(0)
}

func (app *Config) shutdown() {
	app.InfoLog.Println("Shutting down... Cleaning up ...")

	app.cancelRollup() // stop the refresher
	app.Wait.Wait()    // now this actually blocks on something

	app.InfoLog.Println("Shutdown complete. Bye!")
}
