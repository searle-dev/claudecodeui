# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Development
```bash
# Start development environment (both frontend and backend)
npm run dev

# Start individual services
npm run server    # Backend only (Express + WebSocket)
npm run client    # Frontend only (Vite dev server)

# Build for production
npm run build

# Start production server (requires build first)
npm run start
```

### Using the Restart Script
```bash
# Restart development environment (recommended)
./restart.sh

# Restart for production
./restart.sh prod

# View help
./restart.sh --help
```

### Lint and Type Checking
The project uses automatic linting and type checking, but specific commands are not defined. When making changes, always run:
```bash
npm run build  # This will catch most issues
```

## Architecture Overview

### System Architecture
This is a full-stack web application that provides a UI for Claude Code CLI:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │  Claude CLI     │
│   (React/Vite)  │◄──►│ (Express/WS)    │◄──►│  Integration    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Backend Architecture (Node.js/Express)
- **Main Server**: `server/index.js` - Express server with WebSocket support
- **Authentication**: Dual system supporting both simple password auth (session-based) and JWT tokens
- **Claude CLI Integration**: `server/claude-cli.js` - Spawns and manages Claude CLI processes
- **Project Management**: `server/projects.js` - Handles project discovery, session parsing, and file operations
- **File System Watcher**: Uses `chokidar` to monitor `~/.claude/projects/` for real-time updates
- **Database**: SQLite for user authentication (JWT system)

### Frontend Architecture (React)
- **Main App**: `src/App.jsx` contains Session Protection System that prevents UI updates during active conversations
- **Authentication**: `src/contexts/AuthContext.jsx` handles both session and JWT authentication
- **WebSocket Communication**: `src/utils/websocket.js` for real-time chat and project updates
- **Responsive Design**: Mobile-first with `src/components/MobileNav.jsx` and adaptive layouts

### Key Data Flows

#### Project Discovery
1. Backend scans `~/.claude/projects/` directory
2. Parses JSONL session files for each project
3. Maintains project configuration in `~/.claude/project-config.json`
4. Real-time updates via file system watcher → WebSocket → Frontend

#### Session Protection System
- **Problem**: WebSocket updates would interrupt active conversations
- **Solution**: `AppContent` tracks active sessions and pauses project updates during conversations
- **Implementation**: `markSessionAsActive()` and `markSessionAsInactive()` in `src/App.jsx`

#### Authentication Flow
1. **Simple Password Auth**: Uses `ACCESS_PASSWORD` environment variable with Express sessions
2. **JWT Auth**: Database-backed user system with token authentication
3. **Middleware**: `server/middleware/auth.js` supports both authentication methods

## Environment Configuration

### Required Environment Variables
```bash
# Server ports
PORT=3008                    # Backend API + WebSocket
VITE_PORT=3009              # Frontend dev server

# Authentication
ACCESS_PASSWORD=claude123    # Simple password auth
SESSION_SECRET=your-secret-key-here-change-in-production

# Project management
PROJECT_BASE_DIR=/root/projects  # Base directory for relative project paths
```

### Project Creation
The system supports both absolute and relative paths:
- Absolute: `/path/to/project` → creates exactly that path
- Relative: `my-app` → creates `${PROJECT_BASE_DIR}/my-app`
- Nested: `nested/deep/project` → creates `${PROJECT_BASE_DIR}/nested/deep/project`

## Critical Implementation Details

### Session Protection System
Located in `src/App.jsx`, this system prevents UI disruption during active conversations:
- Uses `activeSessions` Set to track conversation state
- Filters WebSocket project updates when sessions are active
- Supports both real session IDs and temporary "new-session-*" identifiers

### Authentication Middleware
The `authenticateToken` function in `server/middleware/auth.js` handles both authentication methods:
1. First checks for `req.session.authenticated` (simple password)
2. Falls back to JWT token verification
3. Creates consistent `req.user` object for both methods

### File System Watcher
Uses `chokidar` to watch `~/.claude/projects/` with optimized settings:
- Ignores common directories (`node_modules`, `.git`, etc.)
- Debounced updates to prevent excessive notifications
- Clears directory cache on file changes

### Claude CLI Integration
- Spawns Claude CLI processes using `node-pty` for full terminal support
- Manages process lifecycle with proper cleanup
- Handles both interactive and non-interactive modes

## Development Patterns

### Adding New API Endpoints
1. Add route to `server/index.js` or create new route file in `server/routes/`
2. Use `authenticateToken` middleware for protected routes
3. Add corresponding API function to `src/utils/api.js`

### WebSocket Message Handling
- Backend sends messages via `connectedClients` Set
- Frontend handles messages in `src/utils/websocket.js`
- Use `type` field to categorize messages (e.g., `'projects_updated'`)

### State Management
- Authentication: `AuthContext` for user state
- Theme: `ThemeContext` for dark/light mode
- Main state: React useState in `App.jsx` (no external state management)

## Testing and Deployment

### Local Development
1. Ensure Claude CLI is installed and configured
2. Copy `.env.example` to `.env` and configure
3. Run `npm install` and `npm run dev`
4. Access at `http://localhost:3009`

### Production Deployment
1. Build: `npm run build`
2. Start: `npm run start` or `./restart.sh prod`
3. Static files served from `dist/` directory
4. Backend serves both API and static assets

The `restart.sh` script handles service management, port checking, and logging automatically.