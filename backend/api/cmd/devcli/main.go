// Command devcli is a DISPOSABLE interactive CLI for driving SHOW during
// development via the /api/dev/* endpoints. Delete this directory (and the
// devtools package) after development.
//
// Usage:
//
//	go run ./cmd/devcli        # talks to http://localhost:8080 by default
//	DEV_API_URL=... go run ./cmd/devcli
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
)

var (
	baseURL = envOr("DEV_API_URL", "http://localhost:8080")
	in      = bufio.NewScanner(os.Stdin)
)

func main() {
	fmt.Printf("SHOW dev CLI → %s\n", baseURL)
	for {
		menu()
		switch strings.TrimSpace(prompt("Choose")) {
		case "1":
			get("/api/dev/users")
		case "2":
			createUser()
		case "3":
			get("/api/dev/users/" + prompt("User id"))
		case "4":
			adjustCredits()
		case "5":
			setPlan()
		case "6":
			setRole()
		case "7":
			notify()
		case "8":
			aiPrompt()
		case "9":
			aiImage()
		case "0", "q", "quit", "exit":
			fmt.Println("bye")
			return
		default:
			fmt.Println("unknown choice")
		}
	}
}

func menu() {
	fmt.Println(`
──────── SHOW dev menu ────────
 1) List users
 2) Create user
 3) Show user detail
 4) Add / deduct credits
 5) Set plan (free | pro_monthly | pro_yearly)
 6) Set role (user | admin)
 7) Send notification
 8) AI: generate prompt
 9) AI: generate image
 0) Quit`)
}

func createUser() {
	body := map[string]any{
		"email":       prompt("Email"),
		"password":    prompt("Password"),
		"displayName": prompt("Display name"),
		"admin":       strings.EqualFold(prompt("Admin? (y/N)"), "y"),
	}
	post("/api/dev/users", body)
}

func adjustCredits() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/credits", map[string]any{
		"delta": atoi(prompt("Delta (negative to deduct)")),
		"note":  prompt("Note"),
	})
}

func setPlan() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/plan", map[string]any{"planId": prompt("Plan id")})
}

func setRole() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/role", map[string]any{"role": prompt("Role")})
}

func notify() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/notify", map[string]any{
		"title": prompt("Title"), "body": prompt("Body"),
	})
}

func aiPrompt() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/ai/prompt", map[string]any{
		"base_prompt": prompt("Base prompt"),
		"model":       optional(prompt("Model (gemini_flash|gpt_luna|gpt_mini, blank=default)")),
	})
}

func aiImage() {
	id := prompt("User id")
	post("/api/dev/users/"+id+"/ai/image", map[string]any{
		"prompt": prompt("Prompt"),
		"model":  optional(prompt("Model (nano_banana_pro|gpt_image, blank=nano)")),
	})
}

// --- HTTP helpers ---

func get(path string) {
	resp, err := http.Get(baseURL + path)
	printResp(resp, err)
}

func post(path string, body any) {
	buf, _ := json.Marshal(body)
	resp, err := http.Post(baseURL+path, "application/json", bytes.NewReader(buf))
	printResp(resp, err)
}

func printResp(resp *http.Response, err error) {
	if err != nil {
		fmt.Println("ERROR:", err)
		return
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	var pretty bytes.Buffer
	if json.Indent(&pretty, data, "", "  ") == nil {
		fmt.Printf("[%d]\n%s\n", resp.StatusCode, pretty.String())
	} else {
		fmt.Printf("[%d] %s\n", resp.StatusCode, string(data))
	}
}

// --- input helpers ---

func prompt(label string) string {
	fmt.Print(label + ": ")
	if !in.Scan() {
		os.Exit(0)
	}
	return strings.TrimSpace(in.Text())
}

func optional(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func atoi(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
