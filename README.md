# All-in-One Recon Framework

## Descripción
Framework de auditoría automatizado diseñado para entornos Windows/WSL. Esta herramienta centraliza tareas críticas de reconocimiento, escaneo y seguridad, optimizando los tiempos de respuesta en evaluaciones de ciberseguridad.

## Características Principales
* **Threat Intel**: Consulta de reputación de IPs mediante integración con la API de AbuseIPDB.
* **Enumeración**: Automatización de búsqueda de subdominios utilizando `subfinder`.
* **Escaneo de Red**: Análisis de servicios y detección de versiones con `nmap`.
* **Fuzzing Web**: Descubrimiento de directorios y rutas ocultas con `ffuf`.
* **Hardening**: Módulo interactivo para aplicar configuraciones de seguridad en servicios (SSH, RDP, SMB).

## Requisitos
* Windows con WSL (Ubuntu) instalado.
* Herramientas necesarias en el entorno Linux:
    * `nmap`
    * `subfinder`
    * `ffuf`

## Instalación y Uso
1. Clona el repositorio:
   ```bash
   git clone [https://github.com/Andres87878888/All-in-One-Recon-Framework.git](https://github.com/Andres87878888/All-in-One-Recon-Framework.git)
