-- Create notes table for Postgres

CREATE TABLE IF NOT EXISTS notes (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_path TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP NOT NULL,
    synced BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at DESC);

-- Sample query to check table
-- SELECT * FROM notes WHERE user_id = 'test-user-123' ORDER BY created_at DESC;
