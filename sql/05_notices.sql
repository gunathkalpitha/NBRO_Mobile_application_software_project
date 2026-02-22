-- ============================================================================
-- NOTICES MODULE (ADMIN -> OFFICERS)
-- ============================================================================

-- Main notices table
CREATE TABLE IF NOT EXISTS notices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('urgent', 'high', 'normal', 'low')),
    target_type TEXT NOT NULL DEFAULT 'all' CHECK (target_type IN ('all', 'individual', 'selected')),
    published_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    published_by_name TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notices_published_at ON notices(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);
CREATE INDEX IF NOT EXISTS idx_notices_target_type ON notices(target_type);
CREATE INDEX IF NOT EXISTS idx_notices_published_by ON notices(published_by);

-- Recipient mapping for individual/selected notices
CREATE TABLE IF NOT EXISTS notice_recipients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    officer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (notice_id, officer_id)
);

CREATE INDEX IF NOT EXISTS idx_notice_recipients_notice_id ON notice_recipients(notice_id);
CREATE INDEX IF NOT EXISTS idx_notice_recipients_officer_id ON notice_recipients(officer_id);
CREATE INDEX IF NOT EXISTS idx_notice_recipients_is_read ON notice_recipients(is_read);

-- Updated-at trigger for notices
DROP TRIGGER IF EXISTS update_notices_updated_at ON notices;
CREATE TRIGGER update_notices_updated_at
    BEFORE UPDATE ON notices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notice_recipients ENABLE ROW LEVEL SECURITY;

-- Admin can create/manage all notices
DROP POLICY IF EXISTS notices_admin_all ON notices;
CREATE POLICY notices_admin_all
    ON notices FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Officers can read notices:
-- 1) global notices (target_type='all')
-- 2) notices addressed to them via notice_recipients
DROP POLICY IF EXISTS notices_officer_read ON notices;
CREATE POLICY notices_officer_read
    ON notices FOR SELECT
    USING (
        target_type = 'all'
        OR EXISTS (
            SELECT 1
            FROM notice_recipients nr
            WHERE nr.notice_id = notices.id
              AND nr.officer_id = auth.uid()
        )
    );

-- Admin can manage recipient mappings
DROP POLICY IF EXISTS notice_recipients_admin_all ON notice_recipients;
CREATE POLICY notice_recipients_admin_all
    ON notice_recipients FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Officers can read/update their own recipient row (for read status)
DROP POLICY IF EXISTS notice_recipients_officer_read ON notice_recipients;
CREATE POLICY notice_recipients_officer_read
    ON notice_recipients FOR SELECT
    USING (officer_id = auth.uid());

DROP POLICY IF EXISTS notice_recipients_officer_update ON notice_recipients;
CREATE POLICY notice_recipients_officer_update
    ON notice_recipients FOR UPDATE
    USING (officer_id = auth.uid())
    WITH CHECK (officer_id = auth.uid());
