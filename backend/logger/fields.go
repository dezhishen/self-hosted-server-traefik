package logger

func String(key, val string) Field {
	return Field{key: key, value: val}
}

func Error(err error) Field {
	return Field{key: "error", value: err}
}

func Int(key string, val int) Field {
	return Field{key: key, value: val}
}

func Any(key string, val interface{}) Field {
	return Field{key: key, value: val}
}
