
//AddThinkToEnt(self, "Think")
stillCounter <- 0
TRACE_DISTANCE <- 48
entitiesHit <- {}
WORLD_STICK_SPEED <- 1000
hitPos <- null
thinkEnabled <- true
activationTime <- Time()


DoEntFire("!self", "CallScriptFunction", "Think", 0.01, self, self)

function Think()
{
	if(!thinkEnabled)
	{
		return
	}
	DoEntFire("!self", "CallScriptFunction", "Think", 0.04, self, self)

	if(!("gunScript" in this))
	{
		return
	}
	
	if(CheckStillSyringe())
	{
		return
	}

	if(TraceDirectHit())
	{
		thinkEnabled = false
	}

}


function TraceDirectHit()
{
	local traceTable =
	{
		start = self.GetOrigin()
		end = self.GetOrigin() + VectorFromQAngle(self.GetAngles(), TRACE_DISTANCE)
		ignore = self
		mask = DirectorScript.TRACE_MASK_SHOT
		//mask =  0x1 | 0x2 | 0x4 | 0x8 | 0x2000 | 0x4000 | 0x2000000 | 0x40000000
		//mask = DirectorScript.TRACE_MASK_ALL
	}
	//DebugDrawLine(traceTable.start, traceTable.end, 0, 255, 0, false, 0.11)
	TraceLine(traceTable)
	
	if(traceTable.hit)
	{
		if("enthit" in traceTable && traceTable.enthit.GetEntityIndex() > 0)
		{
			if(traceTable.enthit != usingPlayer || Time() - activationTime > 1)
			{
				printl("Syringe hit entity: " + traceTable.enthit)		
				return DoHitEffects(traceTable.enthit, traceTable.pos, self.GetAngles())
			}
		}
		else if(GetPhysVelocity(self).Length() > WORLD_STICK_SPEED)
		{
			SpawnSyringeStuck(traceTable.pos, self.GetAngles(), traceTable.enthit)
			return true
		}
	}
	return false
}


function DoHitEffects(entityHit, position, angles)
{		
	entityHit.TakeDamage(0, (1 << 1), usingPlayer)
	
	if(entityHit.GetClassname() == "player")
	{
		EmitSoundOnClient("Adrenaline.NeedleIn", usingPlayer)
		if(entityHit.IsSurvivor())
		{
			EmitSoundOnClient("Adrenaline.NeedleIn", entityHit)
			
			if(entityHit.IsIncapacitated())
			{
				entityHit.ReviveFromIncap()
			}
		
			entityHit.UseAdrenaline(5)
			DoEntFire("!self", "SpeakResponseConcept", "UseAdrenaline", 0.5, entityHit, entityHit)
			local newHealthBuffer = entityHit.GetHealthBuffer() + gunScript.SYRINGE_HEAL_AMOUNT
			
			local maxHealth = Convars.GetFloat("first_aid_kit_max_heal")//pain_pills_health_threshold
			if(maxHealth && newHealthBuffer + entityHit.GetHealth() > maxHealth)
			{
				local healPercentage = Convars.GetFloat("first_aid_heal_percent")
				local bufferHealAmount = maxHealth - entityHit.GetHealthBuffer() - entityHit.GetHealth()
				local permHealAmount = (gunScript.SYRINGE_HEAL_AMOUNT - bufferHealAmount) * healPercentage
			
				local newHealth = entityHit.GetHealth() + permHealAmount
				newHealthBuffer = maxHealth - newHealth
					
				if(newHealth > maxHealth * healPercentage)
				{
					newHealth = maxHealth * healPercentage
					
					
					if(entityHit.GetHealth() > newHealth)
					{
						newHealth = entityHit.GetHealth()
					}
					
					newHealthBuffer = maxHealth - newHealth
				}
				
				entityHit.SetHealth(newHealth)
			}
			
			entityHit.SetHealthBuffer(newHealthBuffer)
			SpawnStaticSyringe(position, angles, entityHit, true)
		}

		return true
	}
	else if(GetPhysVelocity(self).Length() > WORLD_STICK_SPEED)
	{		
		SpawnSyringeStuck(position, angles, entityHit)
		return true
	}
	return false
}

function CheckStillSyringe()
{
	if(GetPhysVelocity(self).Length() < 5)
	{
		if(stillCounter++ > 5)
		{
			SpawnSyringe(self.GetOrigin(), self.GetAngles(), null)
			return true
		}
	}
	else
	{
		stillCounter = 0
	}
	return false
}


function SpawnSyringe(origin, angles, entity = null)
{
	local keyvalues = clone gunScript.SYRINGE_PICKUP
	keyvalues.origin = origin
	keyvalues.angles = angles
	local syringe = g_ModeScript.CreateSingleSimpleEntityFromTable(keyvalues)

	if(entity)
	{
		DoEntFire("!self", "SetParent", "!activator", 0.05 , entity, syringe)
	}	
	DoEntFire("!self", "Kill", "", 300, syringe, syringe)
	self.Kill()
}


function SpawnSyringeStuck(origin, angles, entity = null)
{
	local keyvalues = clone gunScript.SYRINGE_PICKUP_STUCK
	keyvalues.origin = origin + VectorFromQAngle(angles, -2)
	keyvalues.angles = angles
	local syringe = g_ModeScript.CreateSingleSimpleEntityFromTable(keyvalues)

	if(entity)
	{
		DoEntFire("!self", "SetParent", "!activator", 0.05 , entity, syringe)
	}
	
	keyvalues = clone gunScript.SYRINGE_HIT_EFFECT
	keyvalues.origin = origin
	local effect = g_ModeScript.CreateSingleSimpleEntityFromTable(keyvalues)
	DoEntFire("!self", "Kill", "", 0.5, effect, effect)
	
	DoEntFire("!self", "Kill", "", 300, syringe, syringe)
	self.Kill()
}

function SpawnStaticSyringe(origin, angles, entity = null, isPlayer = false)
{
	local keyvalues = clone gunScript.SYRINGE_STATIC
	keyvalues.origin = origin + VectorFromQAngle(angles, 1)
	keyvalues.angles = angles
	local syringe = g_ModeScript.CreateSingleSimpleEntityFromTable(keyvalues)

	if(entity)
	{
		DoEntFire("!self", "SetParent", "!activator", 0.05 , entity, syringe)
		if(isPlayer)
		{
			DoEntFire("!self", "SetParentAttachmentMaintainOffset", "spine", 0.1 , syringe, syringe)
		}
	}
	
	keyvalues = clone gunScript.SYRINGE_HIT_EFFECT
	keyvalues.origin = origin
	local effect = g_ModeScript.CreateSingleSimpleEntityFromTable(keyvalues)
	DoEntFire("!self", "Kill", "", 0.5, effect, effect)
	
	DoEntFire("!self", "Kill", "", 30, syringe, syringe)
	self.Kill()
}

function VectorFromQAngle(angles, radius = 1.0)
{
	local function ToRad(angle)
	{
		return (angle * PI) / 180;
	}
   
	local yaw = ToRad(angles.Yaw());
	local pitch = ToRad(-angles.Pitch());
   
	local x = radius * cos(yaw) * cos(pitch);
	local y = radius * sin(yaw) * cos(pitch);
	local z = radius * sin(pitch);
   
	return Vector(x, y, z);
}