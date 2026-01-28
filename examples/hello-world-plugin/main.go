package main

import (
	"fmt"
	"os"
)

func main() {
	name := os.Getenv("MOLTBOT_USER")
	if name == "" {
		name = "human"
	}
	fmt.Printf("Hello, %s. I am a very serious assistant.\n", name)
	fmt.Println("Fun fact: this plugin does one thing, and it does it with conviction.")
}
