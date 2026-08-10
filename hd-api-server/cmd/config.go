package main

import (
	"database/sql"
	"log"
	"sync"

	"hd-api-server/data"
)

// shared application config
type Config struct {
	DB       *sql.DB
	InfoLog  *log.Logger
	ErrorLog *log.Logger
	Wait     *sync.WaitGroup
	Models   data.Models // our models for accessing the database
}
