
include "wac/base.lua"

local bMZoomed=false
local lastzoomed=0
local pressrmb=false
local lastw


local function sprinting()
	if p and IsValid(p) then
		local b=((p:KeyDown(IN_SPEED) and (p:GetVelocity():Length()+10)>100))
		if
			b
			and (
				p:GetActiveWeapon().NDS_Allocated
				or p:GetActiveWeapon().wac_swep_alt
			)
			and p:GetActiveWeapon():GetClass() != "weapon_physgun"
		then
			p:ConCommand("-attack")
			p:ConCommand("-attack2")
			return true
		end
		return false
	end
end


local function zoomed(w)
	local p=LocalPlayer()
	if lastw!=w then
		bMZoomed=false
		lastw=w
	else
		if w.Author=="Worshipper" then
			bMZoomed=w:GetDTBool(1)		
		else
			if p and p:GetCanZoom() and w and !w.NoZoom and !sprinting(p) and w:GetSequence()!=w:LookupSequence("reload") then
				if p:KeyDown(IN_ATTACK2) then
					if !pressrmb and lastzoomed<CurTime() then
						lastzoomed=CurTime()+0.2
						bMZoomed=!bMZoomed
					end
					pressrmb=true
				else
					pressrmb=false
				end
			else
				bMZoomed=false
			end
		end
	end
	return bMZoomed
end

local oldZoom 		=0
local OldAng 			=Angle(0,0,0)
local blackscreend		=false
local VMPosAdd=Vector(0,0,0)
local CVars={
	Allow=CreateClientConVar("wac_cl_wep_allview", 1, true, true),
	OffsetY=CreateClientConVar("wac_cl_wep_yoffset", 0, true, false),
	fov=CreateClientConVar("wac_cl_wep_fovmod", 0, true, false),
	bounce=CreateClientConVar("wac_cl_wep_bounce", 0.6, true, false),
}

local CV={
	CC=CreateClientConVar("wac_cl_customcrosshair", 0, true, true)
}

local function CheckSwep(self)
	if GetGlobalBool("WAC_DISABLE_AIM") or self.wac_weaponview_ignore then return end
	if IsValid(self) and !self.wac_swep_alt and !self.NDS_Allocated then
		self.NDS_Allocated=true
		--[[self.Zoomed=function()
			return zoomed(self)
			--return (self:GetDTBool(1) or self.InZoom)
		end]]
		self.Holstered=function() end
		self.VMPosMax		= Vector(3, 0, 5)
		self.VMPosM			= Vector(0.08, 0.05, 0.05)*0.35
		self.VMPosMz		= Vector(0.08, 0.05, 0.05)*0.2
		self.VMPosOffset	= Vector(0,0,0)
		self.VMPosD			= Vector(0.15, 0.15, 0.15)
		self.VMPosDz		= Vector(0.16, 0.16, 0.16)*2
		self.VMPosMaxz		= Vector(4, 0, 4)
		self.VMAngM			= Vector(0.4, 0.4, 0)*0
		self.VMAngMax		= Vector(0, 0, 0)
		self.VMPosAdd 		= Vector(0,0,0)
		self.VMAngAdd 		= Angle(0,0,0)
		self.VMAngAddO		= Angle(0,0,0)
		self.DrawCrosshair	= false
		self.Sway			= 0.1
		self.AngM			= .01
		self.AngMax			= 50
		self.AngMz			= 0.001
		self.AngMaxz		= 5
		self.zoomAdd		= 0
		self.zoomStart		= 0
		self.SwayScale 		= 0
		self.BobScale 		= 0
		if file.Exists("wac/weapons/"..self:GetClass()..".lua", "LUA") then
			local data = include("wac/weapons/"..self:GetClass()..".lua")
			if data.disable then
				self.wac_weaponview_ignore = true
				return
			end
			self.AimPos = data.pos
			self.RunPos = data.runpos
			self.AimAng = data.ang
			self.RunAng = data.runang
			self.NoZoom = !data.zoom
			if data.nolag then
				self.VMAngM=Vector(10,10,10)
				self.VMAngMax=Vector(10,10,10)
				self.Sway=0
			end
			self.IniCrosshair = data.crosshair
		else
			local p=self.IronSightsPos
			self.AimPos=self.IronSightsPos
			if self.AimPos then
				self.VMPosMz=self.VMPosMz*(1-self.AimPos.y/4)
				self.VMPosMaxz=self.VMPosMaxz*(1-self.AimPos.y/4)
			else
				self.AimPos=Vector(0,0,0)
			end
			local a=self.IronSightsAng
			self.AimAng=(a and Angle(a.x,a.y,a.z)*(self.ViewModelFlip and -1 or 1) or Angle(0,0,0))
			a=self.RunArmAngle
			self.RunAng=(a and Angle(-a.x,-a.y,-a.z) or Angle(15, 0, 0))
			self.RunPos=(self.RunArmOffset or Vector(-5,-2,2))
			if !self.ViewModelFlip and self.RunPos then
				self.RunPos.x=self.RunPos.x*-1
			elseif self.ViewModelFlip and self.RunAng and self.AimAng then
				self.RunAng.y=self.RunAng.y*-1
				self.AimAng.y=self.AimAng.y*-1
			end		
		end
		self.zmFull=false
		return true
	end
	return false
end

local function CheckAllow(self, p)
	if !p:Alive() or p:InVehicle() or p:GetViewEntity()!=p then return false end
	if CVars.Allow:GetInt()==1 or self.wac_swep_alt then return true end
	return false
end

function ChangeZoom(ply, bind)
	local self = ply:GetActiveWeapon()
	if GetGlobalBool("WAC_DISABLE_AIM") or self.wac_weaponview_ignore then return end
	if self.wac_swep_alt and zoomed(self) and self.zmFull and self.zoomEnd then
		if bind=="invprev" then
			self.zoomAdd=math.Clamp(self.zoomAdd+1,0,self.zoomEnd-self.zoomStart)
			return true
		elseif bind=="invnext" then
			self.zoomAdd=math.Clamp(self.zoomAdd-1,0,self.zoomEnd-self.zoomStart)
			return true
		end
	end
	if CheckAllow(self, ply) and (bind=="+attack" or bind=="+attack2") and (ply:GetActiveWeapon():GetClass() != "weapon_physgun") then
		if sprinting(ply) then return true end
	end
end
wac.hook("PlayerBindPress", "wac_selfs_modifyzoom_alt", ChangeZoom)

local function AddRecoil(um)
	if GetGlobalBool("WAC_DISABLE_AIM") then return end
	local wep = LocalPlayer():GetActiveWeapon()
	if um:ReadBool() then
		wep.RecoilTime = CurTime()+0.1
	end
	if wep.FakeUnzoom and wep.Zoomed then
		timer.Simple(wep.Primary.Delay*0.1, function()
			wep.FakeZoomTime = CurTime() + wep.ReZoomTime
		end)
	end
end
usermessage.Hook("wac_self_alt_addrecoil", AddRecoil)

local lastzoom=0
wac.hook("Think", "wac_cl_weapon_zoomthink", function()
	local crt=CurTime()
end)

local viewtime = 0

local vars = {
	zoom = 0,
	holster = 0,
	ground = 0,
	speed = Vector(0,0,0),
	collide = Vector(0,0,0),
	ang = Angle(0,0,0),
	angAdd = Angle(0,0,0),
	sprinting = 0,
	zoomAdd = 0,
	smoothen = function(self, lvel, weapon, FrT, tr, pvel, vang, ang, flip, delta)
		viewtime = viewtime+math.Clamp(lvel/150,0.1,2)*FrT+0.0001
		self.zoom = wac.smoothApproach(self.zoom,(zoomed(weapon))and(1)or(0),60,20)
		self.holster = wac.smoothApproach(self.holster,(weapon.Holstered(weapon))and(1)or(0),50,5)
		self.sprinting = wac.smoothApproach(self.sprinting,(sprinting(weapon.Owner)or((weapon:GetClass()=="w_wac_test")and(GetConVar("wac_cl_wep_help_sprint"):GetInt()==1)))and(1)or(0),50,15)
		self.zoomAdd = wac.smoothApproach(self.zoomAdd, weapon.zoomAdd, 30)
		self.ground = wac.smoothApproach(self.ground, (weapon.Owner:OnGround())and(1)or(0), 50, 15)
		self.ang.p = wac.smoothApproach(self.ang.p, weapon.VMAngAdd.p, 150, 200)
		self.ang.y = wac.smoothApproach(self.ang.y, weapon.VMAngAdd.y, 150, 200)
		self.ang.r = wac.smoothApproach(self.ang.r, weapon.VMAngAdd.r, 150, 200)
		--wac.smoothApproachVector(v_smWall, tr.StartPos+tr.Normal*23-tr.HitPos, 25)
		--wac.smoothApproachVector(vars.speed, pvel*0.6, 25)
		self.speed.x = math.Clamp(self.speed.x,-700,700)
		self.speed.y = math.Clamp(self.speed.y,-700,700)
		self.speed.z = math.Clamp(self.speed.z,-700,700)
		--self.angAdd.p = wac.smoothApproachAngle(self.angAdd.p, math.AngleDifference(vang.p,ang.p), 50)
		--self.angAdd.y = wac.smoothApproachAngle(self.angAdd.y, math.AngleDifference(vang.y,ang.y)*flp, 50)
	end
}

local v_smSway=Vector(0,0,0)
local zoomrmb=false
local lastzoom=0
wac.hook("CreateMove", "wac_self_alt_recoil", function(user)
	local pl = LocalPlayer()
	local self = pl:GetActiveWeapon()
	if GetGlobalBool("WAC_DISABLE_AIM") or self.wac_weaponview_ignore then return end
	local PViewAngles = user:GetViewAngles()
	if !CheckAllow(self, pl) or !IsValid(self) or CheckSwep(self) then return end
	local add = PViewAngles
	local vel = pl:GetVelocity()
	local lvel = vel:Length()
	local crt = CurTime()
	local self=pl:GetActiveWeapon()
	if pl:KeyDown(IN_ATTACK2) then
		if lastzoom<crt then
			if !self.NoZoom and !zoomrmb then
				self.InZoom=!self.InZoom
				zoomrmb=true
				lastzoom=crt+0.2
			end
		end
	else
		zoomrmb=false
	end
	local vm=pl:GetViewModel()
	if self.InZoom and (vm:GetSequence()==vm:LookupSequence("reload") or sprinting(pl)) then
		self.InZoom=false
	end
	local FrT=math.Clamp(FrameTime(), 0.001, 0.035)
	if self.RecoilTime and self.RecoilTime > crt then
		local maxrec = self.Primary.Recoil
		if zoomed(self) then
			maxrec = maxrec-maxrec/3
		end
		if pl:KeyDown(IN_DUCK) then
			maxrec = maxrec-maxrec/3
		end
		if lvel > 0 then
			maxrec = maxrec + lvel/500
		end
		local mul=(self.RecoilTime-crt)
		if (zoomed(self) and !self.SendZoomedAnim) then
			VMPosAdd.y=math.Clamp(self.BackPushY*mul*1000*FrT, -3, 3)
			VMPosAdd.z=math.Clamp(self.BackPushZ*mul*1000*FrT, -3, 3)
		elseif (!zoomed(self) and !self.SendShootAnim) then
			VMPosAdd.y=math.Clamp(self.BackPushNY*mul*1000*FrT, -3, 3)
			VMPosAdd.z=math.Clamp(self.BackPushNZ*mul*1000*FrT, -3, 3)		
		end
		add = add + Angle(math.Rand(-maxrec*0.5, -maxrec*2)*mul*300*FrT, math.Rand(-maxrec*2, maxrec*2)*mul*300*FrT, 0)
	end
	if (self.wac_swep_alt and self:Zoomed()) and self.ZoomOverlay and self.zmFull then
		add = add + Angle(math.AngleDifference(OldAng.p,PViewAngles.p)*(vars.zoomAdd/28+0.2), math.AngleDifference(OldAng.y,PViewAngles.y)*(vars.zoomAdd/28+0.2), math.AngleDifference(OldAng.r,PViewAngles.r)*0.85)
	end
	add.p=math.Clamp(add.p,-90+10*vars.sprinting,90-vars.sprinting*30)
	OldAng=add
	local m=(pl:KeyDown(IN_DUCK) and 0.5 or 1)
	m=(zoomed(self) and m*0.8 or m*1)
	--wac.smoothApproachVector(v_smSway,VectorRand()*0.5*m,10)
	add=add+Angle(v_smSway.x,v_smSway.y,0)*self.Sway
	user:SetViewAngles(add)
end)


wac.hook("HUDPaint", "wac_cl_customcrosshair_paint", function()
	local p=LocalPlayer()
	local wep=p:GetActiveWeapon()
	if !IsValid(p) or !p:Alive() or !IsValid(wep) then return end
	if GetGlobalBool("WAC_DISABLE_AIM") or wep.wac_weaponview_ignore then return end
	
	if
			CheckAllow(wep, p)
			and (
				(
					(
						GetConVar("wac_allow_crosshair")
						and GetConVar("wac_allow_crosshair"):GetInt()==1
					)	or (
						wep:GetClass() == "gmod_tool" or wep:GetClass() == "weapon_physgun"
					)
				) and (
					CV.CC:GetInt()==1
					or wep.IniCrosshair
				)
			)
			and !sprinting(p)
			and !zoomed(wep)
	then
		local pos = util.QuickTrace(p:EyePos(),p:GetAimVector()*1000,p).HitPos:ToScreen()
		
		surface.SetDrawColor(255,255,255,255)
		surface.SetTexture(surface.GetTextureID("VGUI/crosshair"))
		surface.DrawTexturedRect(pos.x-32, pos.y-32, 64, 64)

		--[[
		surface.SetDrawColor(255,255,255,255)
		surface.DrawLine(pos.x - 11, pos.y, pos.x - 9, pos.y)
		surface.DrawLine(pos.x + 10, pos.y, pos.x + 12, pos.y)
		surface.DrawLine(pos.x, pos.y - 9, pos.x, pos.y - 7)
		surface.DrawLine(pos.x, pos.y + 8, pos.x, pos.y + 10)
		surface.DrawLine(pos.x, pos.y, pos.x, pos.y+1)
		]]

	end
	if p:Alive() and IsValid(wep) and wep:GetClass()=="w_wac_test" then
		local pos=util.QuickTrace(p:EyePos(),p:GetAimVector()*99999,p).HitPos:ToScreen()
		surface.SetDrawColor(255,255,255,255)
		surface.DrawLine(pos.x-10,pos.y,pos.x+10,pos.y)
		surface.DrawLine(pos.x,pos.y+10,pos.x,pos.y-10)
	end
end)

local view={}
local viewang
local oldang
local lastpos=Vector(0,0,0)

wac.hook("HUDShouldDraw", "wac_weapons_hidehud", function(name)
	local player = LocalPlayer()
	if !IsValid(player) then return end
	local weapon = player:GetActiveWeapon()
	if CheckAllow(weapon, player) and name == "CHudCrosshair" then
		return false
	end
end)

wac.hook("CalcView", "wac_weapons_cview", function(p, pos, ang, fov)
	local pl=LocalPlayer()
	if pl:InVehicle() or !pl:Alive() then return end
	local self=p:GetActiveWeapon()
	if GetGlobalBool("WAC_DISABLE_AIM") or self.wac_weaponview_ignore then return end
	if !IsValid(self) then return end
	if !CheckAllow(self, pl) then
		viewang=ang
		oldang=ang
		viewang.r=0
		oldang.r=0
		return
	end
	if CheckSwep(self) then return end
	local vel=pl:GetVelocity()
	local lvel=vel:Length()
	local FrT=FrameTime()
	local crt = CurTime()
	viewang = viewang or ang
	oldang = oldang or ang
	local PDiff = math.AngleDifference(viewang.p, ang.p)
	local YDiff = math.AngleDifference(viewang.y, ang.y)
	local aPDiff=math.AngleDifference(oldang.p,ang.p)
	local aYDiff=math.AngleDifference(oldang.y,ang.y)
	viewang.p = viewang.p-((PDiff*math.Clamp(math.abs(PDiff),self.AngM,self.AngMax)*0.01)*(1-vars.zoom)+(PDiff*math.Clamp(math.abs(PDiff),self.AngMz,self.AngMaxz)*0.1)*vars.zoom)
	viewang.y = viewang.y-((YDiff*math.Clamp(math.abs(YDiff),self.AngM,self.AngMax)*0.01)*(1-vars.zoom)+(YDiff*math.Clamp(math.abs(YDiff),self.AngMz,self.AngMaxz)*0.1)*vars.zoom)
	viewang.r=0
	VMPosAdd.x = math.Clamp(VMPosAdd.x - (1-math.abs(VMPosAdd.x)/self.VMPosMax.x)*aYDiff*(self.VMPosM.x*(1-vars.zoom)+self.VMPosMz.x*vars.zoom)*math.Clamp(70-math.abs(ang.p),-30,30)/30 - VMPosAdd.x*(self.VMPosD.x*(1-vars.zoom)+self.VMPosDz.x*vars.zoom), -(self.VMPosMax.x*(1-vars.zoom)+self.VMPosMaxz.x*vars.zoom), self.VMPosMax.x*(1-vars.zoom)+self.VMPosMaxz.x*vars.zoom)
	VMPosAdd.z = math.Clamp(VMPosAdd.z - (1-math.abs(VMPosAdd.z)/self.VMPosMax.z)*aPDiff*(self.VMPosM.z*(1-vars.zoom)+self.VMPosMz.z*vars.zoom)*math.Clamp(70-math.abs(ang.p),-30,30)/30 - VMPosAdd.z*(self.VMPosD.z*(1-vars.zoom)+self.VMPosDz.z*vars.zoom), -(self.VMPosMax.z*(1-vars.zoom)+self.VMPosMaxz.z*vars.zoom), self.VMPosMax.z*(1-vars.zoom)+self.VMPosMaxz.z*vars.zoom)
	if (vars.zoom >= 0.9 and zoomed(self) and self.ZoomOverlay and !self.zmFull) then
		self.zmFull = true
		self.zoomBlack=255
		pl:GetViewModel():SetNoDraw(true)
	elseif self.zmFull and vars.zoom < 0.9 then
		self.zmFull = false
		pl:GetViewModel():SetNoDraw(false)
	end
	local ri = viewang:Right()
	local up = viewang:Up()
	local fwd = viewang:Forward()
	local VMFlip = (self.ViewModelFlip)and(-1)or(1)
	local VMFlop = 0-VMFlip
	local pvel = pl:WorldToLocal(pl:GetPos()+(pos-lastpos)*100)
	lastpos = pos
	local runsinx = math.sin(viewtime*14)*vars.ground
	local runsiny = math.sin(viewtime*7)*vars.ground
	local tr=util.QuickTrace(pos,ang:Forward()*23,self.Owner)
	vars:smoothen(lvel, self, FrT, crt, tr, pvel, viewang, ang, VMFlip, lastdelta)
	fwd.z=math.Clamp(fwd.z,-1,(1-vars.sprinting))
	local m=(0.1*math.Clamp(1-vars.zoom,0.01,1)*(p:KeyDown(IN_DUCK) and 0.1 or 1))
	pos=pos+runsinx*up*3*math.Clamp(lvel*lvel*0.00001,m,10)*CVars.bounce:GetFloat()+ri*runsiny*3*math.Clamp(lvel*lvel*0.00001, m, 10)*CVars.bounce:GetFloat()
	--[[local eyes=p:GetAttachment(p:LookupAttachment("eyes"))
	pos=eyes.Pos]]
	view.origin=pos
	view.fov = math.Clamp(fov - (self.zoomStart+((vars.zoomAdd+20+(fov-90))*((vars.zoom>=0.9 and self.zoomEnd) and 1 or 0)))*vars.zoom+CVars.fov:GetFloat(), 1.5, 100)
	if self.ScopeModel then
		self.ScopeModel:SetPos(pos+vars.speed.x*fwd*-0.01+vars.speed.y*ri*0.002+vars.speed.z*up*-0.002)
		self.ScopeModel:SetAngles(viewang-Angle(vars.angAdd.p,vars.angAdd.y*VMFlip,vars.angAdd.r))
		self.ScopeModel:SetModelScale(Vector(0.5, view.fov/100, view.fov/100))
	end
	--local vmang=viewang-vars.angAdd*0.7+Angle(self.RunAng.p*vars.sprinting-ang.p*vars.sprinting, self.RunAng.y*vars.sprinting*VMFlop+ang.p*vars.sprinting*0.4*VMFlip, ang.p*vars.sprinting*0.5*VMFlip)*(1-vars.holster)
	local vmang = viewang-vars.angAdd*0.7+Angle(self.RunAng.p*vars.sprinting, self.RunAng.y*vars.sprinting*VMFlop, self.RunAng.r*vars.sprinting)*(1-vars.holster)
	vmang = vmang+Angle((vars.ang.p+self.AimAng.p*vars.zoom)*(1-vars.sprinting), (vars.ang.y+self.AimAng.y*vars.zoom)*VMFlip*(1-vars.sprinting), self.AimAng.r*vars.zoom*(1-vars.sprinting))*(1-vars.holster)+Angle(vars.holster*90,(vars.holster*-90+runsiny*2*vars.sprinting)*VMFlip+runsiny*5*vars.sprinting*VMFlop,0)
	pos = pos+ri*(runsiny*-m*VMFlip+runsiny*lvel*0.001+self.VMPosOffset.x*(1-vars.sprinting)*(1-vars.zoom) +math.Clamp(ang.p*0.05*vars.sprinting,0,30)*VMFlip +vars.speed.y*VMFlip*(1.5-vars.zoom)*0.004 +VMPosAdd.x*VMFlip + VMFlip*(self.VMAngAdd.y)*(1-vars.zoom)*0.1 +self.RunPos.x*vars.sprinting*VMFlop +runsiny*vars.sprinting +self.AimPos.x*vars.zoom-runsiny*vars.sprinting)
	pos = pos+fwd*(CVars.OffsetY:GetFloat()*(1-vars.zoom)*(1-vars.sprinting)+self.VMPosOffset.y*(1-vars.sprinting)*(1-vars.zoom) -vars.speed.x*(1.5-vars.zoom)*0.004 -vars.holster*10+VMPosAdd.y +self.RunPos.y*vars.sprinting +self.AimPos.y*vars.zoom-runsiny*vars.sprinting)
	pos = pos+up*(runsinx*-m+runsinx*lvel*0.001+self.VMPosOffset.z*(1-vars.sprinting)*(1-vars.zoom) -math.Clamp(ang.p*0.05*vars.sprinting,0,30) -vars.speed.z*(2-vars.zoom)*0.004 +VMPosAdd.z -vars.speed:Length()*0.002*(1-vars.zoom) +(self.VMAngAdd.p)*(1-vars.zoom)*0.1 +self.RunPos.z*vars.sprinting +runsinx*0.5*vars.sprinting +self.AimPos.z*vars.zoom)
	--view.angles=ang+Angle(runsinx*math.Clamp(lvel/300*vars.ground, 0.1, 1), runsiny*math.Clamp(lvel/300*vars.ground, 0.1, 1), 0)
	view.angles = viewang+Angle(0+runsinx*0,0,vars.speed.y*-0.0125)*(lvel/250)*vars.ground*CVars.bounce:GetFloat()
	view.vm_angles = vmang
	view.vm_origin = pos-vars.collide*(1-vars.zoom)
	view.znear=1
	return view
end)


