# Contributing to GMADP

## Development Workflow

### Initial Setup
1. Clone the repository
2. Create virtual environment: `python3 -m venv venv`
3. Activate environment: `source venv/bin/activate`
4. Install dependencies: `pip install -r requirements.txt`
5. Copy `.env.example` to `.env` and configure

### Making Changes
1. Create a new branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Test your changes locally
4. Commit your changes: `git commit -m "Description of changes"`
5. Push to your branch: `git push origin feature/your-feature-name`
6. Create a Pull Request

### Deployment Workflow
- **Development**: Work on feature branches
- **Staging**: Merge to `develop` branch for testing
- **Production**: Merge to `main` branch triggers deployment

### Pre-commit Checks
- Python syntax validation
- File size checks
- Sensitive file prevention (.env, database files)

### Deployment
- Automatic deployment via GitHub Actions
- Webhook-based deployment for real-time updates
- Manual deployment using `github-deploy.sh`

## Code Style
- Follow PEP 8 for Python code
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Testing
- Write tests for new features
- Run tests before committing
- Ensure all tests pass in CI/CD pipeline

## Security
- Never commit sensitive data (.env files, API keys)
- Use environment variables for configuration
- Follow security best practices for web applications

## Documentation
- Update README.md for new features
- Document API endpoints
- Include deployment instructions
