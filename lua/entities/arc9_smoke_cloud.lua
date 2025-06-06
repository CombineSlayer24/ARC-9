ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "Smoke Cloud"
ENT.Author = ""
ENT.Information = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false

local smokeimages = {"particle/smokesprites_0002", "particle/smokesprites_0003", "particle/smokesprites_0004", "particle/smokesprites_0005", "particle/smokesprites_0006", "particle/smokesprites_0007", "particle/smokesprites_0008", "particle/smokesprites_0009", "particle/smokesprites_0010", "particle/smokesprites_0011", "particle/smokesprites_0012", "particle/smokesprites_0013", "particle/smokesprites_0014", "particle/smokesprites_0015", "particle/smokesprites_0016"}

local function GetSmokeImage()
    return smokeimages[math.random(#smokeimages)]
end

ENT.Particles = nil
ENT.SmokeRadius = 256
ENT.SmokeColor = Color(150, 150, 150)
ENT.BillowTime = 1
ENT.Life = 15

ENT.ARC9Smoke = true
ENT.ArcCWSmoke = true

AddCSLuaFile()

function ENT:Initialize()
    local mins, maxs = Vector(-self.SmokeRadius / 2, -self.SmokeRadius / 2, -self.SmokeRadius / 2), Vector(self.SmokeRadius / 2, self.SmokeRadius / 2, self.SmokeRadius / 2)
    self.SmokeRadiusSqr = self.SmokeRadius * self.SmokeRadius
    if SERVER then
        self:SetModel( "models/weapons/w_eq_smokegrenade_thrown.mdl" )
        self:PhysicsInitSphere(self.SmokeRadius / 2)
        self:SetCollisionBounds(mins, maxs)
        self:SetMoveType( MOVETYPE_NONE )
        self:SetSolid( SOLID_NONE )
        self:DrawShadow( false )
    else
        local emitter = ParticleEmitter(self:GetPos())

        self.Particles = {}

        local amt = 20

        for i = 1, amt do
            local smoke = emitter:Add(GetSmokeImage(), self:GetPos())
            smoke:SetVelocity( VectorRand() * 8 + (Angle(0, i * (360 / amt), 0):Forward() * 400) )
            smoke:SetStartAlpha( 0 )
            smoke:SetEndAlpha( 255 )
            smoke:SetStartSize( 0 )
            smoke:SetEndSize( self.SmokeRadius )
            smoke:SetRoll( math.Rand(-180, 180) )
            smoke:SetRollDelta( math.Rand(-0.2,0.2) )
            smoke:SetColor( self.SmokeColor.r, self.SmokeColor.g, self.SmokeColor.b )
            smoke:SetAirResistance( 75 )
            smoke:SetPos( self:GetPos() )
            smoke:SetCollide( true )
            smoke:SetBounce( 0.2 )
            smoke:SetLighting( false )
            smoke:SetNextThink( CurTime() + FrameTime() )
            smoke.bt = CurTime() + self.BillowTime
            smoke.dt = CurTime() + self.BillowTime + self.Life
            smoke.ft = CurTime() + self.BillowTime + self.Life + math.Rand(2.5, 5)
            smoke:SetDieTime(smoke.ft)
            smoke.life = self.Life
            smoke.billowed = false
            smoke.radius = self.SmokeRadius
            smoke:SetThinkFunction( function(pa)
                if !pa then return end

                local prog = 1
                local alph = 0

                if pa.ft < CurTime() then
                    pa:SetDieTime(0)
                    return
                elseif pa.dt < CurTime() then
                    local d = (CurTime() - pa.dt) / (pa.ft - pa.dt)

                    alph = 1 - d
                elseif pa.bt < CurTime() then
                    alph = 1
                else
                    local d = math.Clamp(pa:GetLifeTime() / (pa.bt - CurTime()), 0, 1)

                    prog = (-d ^ 2) + (2 * d)

                    alph = d
                end

                pa:SetEndSize( pa.radius * prog )
                pa:SetStartSize( pa.radius * prog )

                pa:SetStartAlpha(255 * alph)
                pa:SetEndAlpha(255 * alph)

                pa:SetNextThink( CurTime() + FrameTime() )
            end )

            table.insert(self.Particles, smoke)
        end

        emitter:Finish()
    end

    self:EnableCustomCollisions()
    self:SetCustomCollisionCheck(true)
    self:CollisionRulesChanged()

    self.dt = CurTime() + self.Life + self.BillowTime
end

function ENT:Think()

    if SERVER then
        local targets = ents.FindInSphere(self:GetPos(), 256)
        for _, k in pairs(targets) do
            if k:IsNPC() then
                k:SetSchedule(SCHED_STANDOFF)
            end
        end
    end

    if self.dt < CurTime() then
        if SERVER then
            SafeRemoveEntity(self)
        end
    end
end

function ENT:Draw()
    return false
end

function ENT:TestCollision( startpos, delta, isbox, extents, mask )
    if (mask == MASK_BLOCKLOS or mask == MASK_BLOCKLOS_AND_NPCS) then
        local len = delta:Length()
        if len <= 128 then return false end -- NPCs can see very close

        local rad = self.SmokeRadiusSqr or (self.SmokeRadius * self.SmokeRadius)
        local pos = self:GetPos()
        local dir = delta:GetNormalized()

        -- Trace started within the smoke
        if startpos:DistToSqr(pos) <= rad then
            return {
                HitPos = startpos,
                Fraction = 0,
                Normal = -dir,
            }
        end

        -- Find the closest point on the original trace to the smoke's origin point
        local t = (pos - startpos):Dot(dir)
        local p = startpos + t * dir

        -- If the point is within smoke radius, the trace is intersecting the smoke
        if p:DistToSqr(pos) <= rad then
            return {
                HitPos = p,
                Fraction = math.Clamp(t / len, 0, 0.95),
                Normal = -dir,
            }
        end
    else
        return false
    end
end

hook.Add("ShouldCollide", "ARC9_Smoke", function(ent1, ent2)
    if ent1.ARC9Smoke and !ent2:IsNPC() then return false end
    if ent2.ARC9Smoke and !ent1:IsNPC()  then return false end
end)