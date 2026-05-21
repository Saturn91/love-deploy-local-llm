return {
    llm = {
        port         = 8080,
        context_size = 2048,
        runtime_dir  = "ollama",      -- subfolder containing llama-server.exe and its DLLs
        model_file   = "model.gguf",  -- looked up next to the game exe (not inside runtime_dir)
        temperature  = 0.7,
        max_tokens   = 512,
        system_prompt = "You are a helpful assistant.",
    }
}
