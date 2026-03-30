# azure-devops-pipeline
<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![CI/CD Pipeline][pipeline-shield]][pipeline-url]
[![Python][python-shield]][python-url]
[![Docker][docker-shield]][docker-url]
[![Azure][azure-shield]][azure-url]
[![License: MIT][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <h1>Azure DevOps CI/CD Pipeline</h1>
  <p>
    A complete CI/CD pipeline that automatically tests, builds, scans, and deploys a containerised Flask application to Azure every time I push to main.
    <br />
    <br />
    <a href="https://github.com/claryzw/azure-devops-pipeline"><strong>Explore the repo »</strong></a>
    <br />
    <br />
    <a href="https://github.com/claryzw/azure-devops-pipeline/actions">View Pipeline Runs</a>
    ·
    <a href="https://github.com/claryzw/azure-devops-pipeline/issues">Report Bug</a>
    ·
    <a href="https://github.com/claryzw/azure-devops-pipeline/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#api-endpoints">API Endpoints</a></li>
    <li><a href="#cicd-pipeline">CI/CD Pipeline</a></li>
    <li><a href="#azure-infrastructure">Azure Infrastructure</a></li>
    <li><a href="#docker-security">Docker Security</a></li>
    <li><a href="#monitoring-and-alerts">Monitoring and Alerts</a></li>
    <li><a href="#project-structure">Project Structure</a></li>
    <li><a href="#what-i-learned">What I Learned</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

<!-- ABOUT THE PROJECT -->
## About The Project

I built this project from scratch to move from Linux server administration into cloud DevOps engineering. Every phase was done hands-on with no pre-made templates.

Here is what the project covers:

* CI/CD pipeline with GitHub Actions that builds, tests, scans, and deploys on every push
* Cloud infrastructure defined as code with Azure Bicep (7 resources)
* Docker containerisation with production security hardening
* Trivy vulnerability scanning inside the CI pipeline
* Automated deployment to Azure App Service from Azure Container Registry
* Application monitoring with Application Insights and OpenTelemetry
* Alert rules that send email when response time or failure rate goes above threshold

The full pipeline takes **3 minutes 30 seconds** from push to live application. Everything is automated with zero manual steps.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

* [![Python][python-shield]][python-url]
* [![Flask][flask-shield]][flask-url]
* [![Docker][docker-shield]][docker-url]
* [![GitHub Actions][actions-shield]][actions-url]
* [![Azure][azure-shield]][azure-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- GETTING STARTED -->
## Getting Started

Follow these steps to get a local copy running.

### Prerequisites

* Python 3.11+
* Docker Desktop
* Git
* Azure CLI (only needed if you want to deploy to Azure)

### Installation

1. Clone the repo
   ```bash
   git clone https://github.com/claryzw/azure-devops-pipeline.git
   cd azure-devops-pipeline
   ```
2. Install Python dependencies
   ```bash
   pip install -r requirements.txt
   ```
3. Run the Flask app locally
   ```bash
   python -m flask --app app.main run --host 0.0.0.0 --port 8000
   ```
4. Or run with Docker
   ```bash
   docker build -t devops-pipeline:latest .
   docker run -p 8000:8000 devops-pipeline:latest
   ```
5. Open `http://localhost:8000` in your browser

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- API ENDPOINTS -->
## API Endpoints

| Route | Response | Purpose |
|---|---|---|
| `/` | HTML page | Home page showing app name, version, and health status |
| `/health` | JSON | Health check returning `{"status": "healthy", "version": "1.0.0"}` |
| `/api/info` | JSON | System info: hostname, Python version, timestamp, environment |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- CI/CD PIPELINE -->
## CI/CD Pipeline

The pipeline runs automatically on every push to `main`. It has two jobs that run one after the other. The CD job only starts if the CI job passes.

### CI: Build, Test & Scan (56 seconds)

| Step | Action |
|---|---|
| 1 | Checkout code |
| 2 | Setup Python 3.11 with pip caching |
| 3 | Install dependencies |
| 4 | Run pytest with 3 automated tests that verify all routes |
| 5 | Run flake8 to lint for PEP 8 compliance |
| 6 | Build Docker image tagged with commit SHA and `latest` |
| 7 | Trivy scan that fails the build on HIGH or CRITICAL vulnerabilities |
| 8-10 | Login, tag, and push image to Azure Container Registry |

### CD: Deploy to Azure (2 min 26 seconds)

| Step | Action |
|---|---|
| 1 | Checkout code for Bicep templates |
| 2 | Azure login with service principal (least-privilege access) |
| 3 | Bicep deploy to create or update all 7 Azure resources |
| 4 | Get ACR credentials dynamically |
| 5 | Build and push fresh image from the deploy runner |
| 6 | Restart Web App to pull the latest container image |
| 7 | Health check that curls `/health` with a 120-second retry loop |

**Total pipeline time: 3 minutes 30 seconds** from push to live deployment.

### GitHub Secrets

The pipeline uses 7 encrypted repository secrets:

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | Service principal application ID |
| `AZURE_CLIENT_SECRET` | Service principal password |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription identifier |
| `AZURE_TENANT_ID` | Azure Active Directory tenant |
| `ACR_LOGIN_SERVER` | Container registry URL (`*.azurecr.io`) |
| `ACR_USERNAME` | Container registry admin username |
| `ACR_PASSWORD` | Container registry admin password |

The service principal has the Contributor role scoped only to the `devops-pipeline-rg` resource group, not the entire subscription.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- AZURE INFRASTRUCTURE -->
## Azure Infrastructure

All resources are defined in `infrastructure/main.bicep` and deployed automatically by the pipeline. Everything runs on the Azure Free Tier.

| # | Resource | Purpose | Free Tier |
|---|---|---|---|
| 1 | Log Analytics Workspace | Centralised logging | 5GB/month free |
| 2 | Application Insights | App performance monitoring | Connected to Log Analytics |
| 3 | Container Registry (Basic) | Private Docker image storage | 10GB free |
| 4 | App Service Plan (F1) | Compute for the web app | 60 min CPU/day |
| 5 | Web App | Flask app running as container | Pulls from ACR |
| 6 | Action Group | Alert email notifications | Free |
| 7 | Metric Alert | Slow response time warning | Free |

**Region:** `australiaeast`

The whole infrastructure can be destroyed and recreated in 60 seconds. I tear down resources after each phase to protect free tier credits, and the pipeline rebuilds everything on the next push.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- DOCKER SECURITY -->
## Docker Security

The Dockerfile includes 5 hardening measures:

| Feature | Why It Matters |
|---|---|
| Slim base image (`python:3.11-slim`) | ~150MB vs ~900MB for the full image. Less code means fewer vulnerabilities. |
| Non-root user (`appuser`) | Follows the principle of least privilege. An attacker who gets in has no admin access. |
| Layer caching | `requirements.txt` is copied first so dependencies are cached when only code changes. |
| Build tool removal | `pip`, `setuptools`, and `wheel` are removed after install. This eliminates Trivy findings. |
| HEALTHCHECK directive | Docker pings `/health` every 30 seconds to check if the app is running. |

**Trivy scan result after remediation: 0 HIGH/CRITICAL vulnerabilities.**

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- MONITORING AND ALERTS -->
## Monitoring and Alerts

Application Insights is integrated into the Flask app using the `azure-monitor-opentelemetry` SDK. Two alert rules monitor the application in production:

| Alert | Condition | Action |
|---|---|---|
| Slow response time | Average response time > 2 seconds for 5 minutes | Email notification |
| High failure rate | Failed request rate > 5% in a 5-minute window | Email notification |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- PROJECT STRUCTURE -->
## Project Structure

```
azure-devops-pipeline/
├── app/
│   ├── __init__.py
│   ├── main.py              # Flask app with 3 routes
│   └── templates/
│       └── index.html        # Home page template
├── tests/
│   └── test_main.py          # 3 pytest tests covering all routes
├── infrastructure/
│   ├── main.bicep             # 7 Azure resources defined in code
│   └── parameters.json        # Environment-specific configuration
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # CI/CD pipeline (17 steps across 2 jobs)
├── Dockerfile                 # Production-ready with 5 security features
├── requirements.txt           # Pinned dependencies
├── .dockerignore              # Keeps build context to 7KB
├── .flake8                    # Linter configuration
└── README.md
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- WHAT I LEARNED -->
## What I Learned

This project taught me that DevOps work goes well beyond writing YAML files. These are the real lessons I took away from it.

**Credential management needs a system.** I tore down and redeployed infrastructure between phases to save free tier credits. This broke role assignments and rotated ACR credentials every time. I had to build a recovery process: recreate the resource group, redeploy Bicep, reassign the Contributor role, and reset the service principal secret.

**YAML indentation matters more than you think.** Two separate indentation errors caused "no jobs were run" failures. The pipeline just silently did nothing because one space was off. After the second time, I learned that downloading a clean generated file is more reliable than editing YAML by hand.

**Always read the actual error.** When OpenTelemetry telemetry was not showing up in Application Insights, I spent time looking for a code bug. The real cause was a platform limitation. The F1 free tier sets `alwaysOn: false`, which means the container shuts down before the telemetry buffer gets a chance to flush. The code was fine. My assumption was wrong.

**Security has to be part of the build.** My first Trivy scan found 82 vulnerabilities in the Docker image. I updated Flask, removed build tools from the production image, and switched to a non-root user. The re-scan came back with zero HIGH/CRITICAL findings. Because Trivy runs in CI, every future push gets checked automatically.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- ROADMAP -->
## Roadmap

- [x] Flask application with health check and info endpoints
- [x] Docker containerisation with security hardening
- [x] Azure Bicep infrastructure as code (7 resources)
- [x] GitHub Actions CI/CD pipeline (17 steps, 3m 30s)
- [x] Monitoring with Application Insights and OpenTelemetry
- [x] Automated alert rules for response time and failure rate
- [x] Architecture diagram
- [ ] Terraform alternative for multi-cloud IaC
- [ ] Staging environment with blue-green deployment

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- CONTACT -->
## Contact

**Clarence Itai Msindo**

System Administrator moving into DevOps Engineering. I have 5 years of IT experience managing Linux servers (CentOS, AlmaLinux) with 99.9% uptime. I wrote automation scripts in Python and Bash that reduced manual work by 60%, and built security policies that cut incidents by 95%.

**Certifications:** Azure Fundamentals (AZ-900) · Azure AI Fundamentals (AI-900) · Google IT Support Professional Certificate

[![LinkedIn][linkedin-shield]][linkedin-url]

Project Link: [github.com/claryzw/azure-devops-pipeline](https://github.com/claryzw/azure-devops-pipeline)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Claude Opus 4.6 (Anthropic)](https://claude.ai/) and [DeepSeek](https://www.deepseek.com/) for AI-assisted coding, debugging, and documentation
* [The DevOps Handbook](https://itrevolution.com/product/the-devops-handbook-second-edition/) by Gene Kim, Jez Humble, Patrick Debois, and John Willis
* [The Phoenix Project](https://itrevolution.com/product/the-phoenix-project/) by Gene Kim, Kevin Behr, and George Spafford
* [GitHub Actions Documentation](https://docs.github.com/en/actions)
* [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
* [Trivy Container Security Scanner](https://github.com/aquasecurity/trivy)
* [OpenTelemetry Python SDK](https://opentelemetry.io/docs/languages/python/)
* [Best-README-Template](https://github.com/othneildrew/Best-README-Template)
* [Img Shields](https://shields.io)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

<!-- MARKDOWN LINKS & IMAGES -->
[pipeline-shield]: https://img.shields.io/github/actions/workflow/status/claryzw/azure-devops-pipeline/ci-cd.yml?branch=main&style=for-the-badge&label=CI%2FCD%20Pipeline
[pipeline-url]: https://github.com/claryzw/azure-devops-pipeline/actions
[python-shield]: https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white
[python-url]: https://www.python.org/
[docker-shield]: https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white
[docker-url]: https://www.docker.com/
[azure-shield]: https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white
[azure-url]: https://azure.microsoft.com/
[license-shield]: https://img.shields.io/badge/License-MIT-green?style=for-the-badge
[license-url]: https://github.com/claryzw/azure-devops-pipeline/blob/main/LICENSE
[linkedin-shield]: https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white
[linkedin-url]: https://www.linkedin.com/in/clarence-itai-msindo
[flask-shield]: https://img.shields.io/badge/Flask-000000?style=for-the-badge&logo=flask&logoColor=white
[flask-url]: https://flask.palletsprojects.com/
[actions-shield]: https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white
[actions-url]: https://github.com/features/actions
