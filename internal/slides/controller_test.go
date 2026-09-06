package slides

import "testing"

func TestParseCommandWithSequence(t *testing.T) {
	action, argument := parseCommand("count|8|42")
	if action != "count" || argument != "8" {
		t.Fatalf("parseCommand() = %q, %q", action, argument)
	}
}

func TestParseRepeatedCommandPayloadsDiffer(t *testing.T) {
	first, _ := parseCommand("next||1")
	second, _ := parseCommand("next||2")
	if first != "next" || second != "next" {
		t.Fatalf("repeated commands parsed as %q and %q", first, second)
	}
}
