FROM microsoft/powershell
MAINTAINER Ryan Butler <ryan@techdrabble.com>
COPY cpx.ps1 /tmp
RUN pwsh -c "Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted" && \
pwsh -c 'install-module netscaler -force -confirm:$false'
ENTRYPOINT ["pwsh", "/tmp/cpx.ps1"]
