# Delete the gpt-rag-ingestion folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-ingestion") {
    Remove-Item -Path ".\.azure\gpt-rag-ingestion" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone -b main-DCS https://github.com/davidxw/gpt-rag-ingestion-DCS .\.azure\gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-orchestrator") {
    Remove-Item -Path ".\.azure\gpt-rag-orchestrator" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone -b main-DCS https://github.com/davidxw/gpt-rag-orchestrator-DCS .\.azure\gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .azure if it exists
if (Test-Path -Path ".\.azure\gpt-rag-frontend") {
    Remove-Item -Path ".\.azure\gpt-rag-frontend" -Recurse -Force
}

# Clone the repository into the .azure folder
git clone -b main-DCS https://github.com/davidxw/gpt-rag-frontend-DCS .\.azure\gpt-rag-frontend
