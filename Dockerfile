FROM mcr.microsoft.com/dotnet/sdk:8.0

# Install prerequisites
RUN apt-get update && \
    apt-get install -y curl wget gnupg apt-transport-https software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# Add Microsoft package repository (required for PowerShell)
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Install PowerShell
RUN apt-get update && \
    apt-get install -y powershell

# Install Node.js 18 (you can upgrade to 20 later)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Copy project
COPY . .

# Make script executable
RUN chmod +x ./scripts/BuildAndReplaceBinaries.ps1

# Run build script
# CMD ["pwsh", "./scripts/BuildAndReplaceBinaries.ps1"]
CMD ["pwsh"]
