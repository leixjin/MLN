---
--- Generated by MLNUI(https://github.com/momotech/MLN)
--- Created by momo.
--- DateTime: 2020-07-18 11:08
---

local _class = {
    ---@private
    _currentIndex = nil,
    _progressBar = nil,
    _subviews = {},
    _animCache = {},
    _onSelected = nil,
    _autoAnimTime = 0.2,
    _viewpager = nil,
    ---@public
    contentView = nil
}
_class._type = 'ui'

---
--- @public
---
function TabSegment(datas)
    local obj = {}
    setmetatable(obj, _class)
    obj._models = datas
    obj.contentView = ScrollView(true):showsHorizontalScrollIndicator(false)
    return obj
end

function _class:setupAnimation(callback)
    if not callback or type(callback) ~= "function" then
        return self
    end
    callback(self)
    return self
end

function _class:animationType(type)
    self._animType = type
    return self
end

function _class:from(f)
    self._from = f
    return self
end

function _class:to(t)
    self._to = t
    return self
end

function _class:setupProgressBar(callback)
    if not callback or type(callback) ~= "function" then
        return self
    end
    local bar = callback()
    if self._progressBar and self._progressBar:superview() then
        self._progressBar:removeFromSuper()
        self._container:addView(bar)
    end
    self._progressBar = bar
    return self
end

function _class:bindCell(callback)
    if not callback or type(callback) ~= "function" then
        return self
    end
    if not self._models or #self._models == 0 then
        self._setupSubviewsCallback = callback
        return self
    end
    self:_create(self._models, callback)
    return self
end

function _class:bindData(datas)
    if not datas or #datas == 0 then
        return self
    end
    self._models = datas
    if self._setupSubviewsCallback then
        self:_create(datas, self._setupSubviewsCallback)
        self._setupSubviewsCallback = nil
    end
    return self
end

function _class:setCurrentIndex(index)
    if not self._isClickTabSegment then
        self._currentIndex = index
    end
    return self
end

function _class:getCurrentIndex()
    return self._currentIndex
end

function _class:scroll(fromIndex, toIndex, progress)
    if not self._isClickTabSegment and fromIndex ~= toIndex then
        self:_updateItemsUI(fromIndex, toIndex, progress, false)
    end
end

function _class:onSelected(callback)
    self._onSelected = callback
end

---
--- @private
---

local function CenterX(view)
    if not view then return 0 end
    return view:getX() + view:width() / 2
end

function _class:_create(models, callback)
    local views = {}
    for _, v in ipairs(models) do
        local tab = callback(v)
        table.insert(views, tab)
    end
    self:_setupUI(views)
end

function _class:_setupUI(views)
    if not views or #views == 0 then
        print("[ArgoUI Warning] The views can not be nil when create TabSegment!")
        return
    end

    local scrollView = self.contentView
    local container = VStack():basis(1):crossSelf(CrossAxis.STRETCH)
    local itemsView = HStack():padding(15, 30, 10, 0):mainAxis(MainAxis.SPACE_EVENLY):crossSelf(CrossAxis.STRETCH):crossAxis(CrossAxis.STRETCH)

    for i, v in ipairs(views) do
        v:marginLeft(30):onClick(function()
            self._isClickTabSegment = true
            self:_clickItem(i, true)
        end)
        table.insert(self._subviews, v)
        itemsView:addView(v)
        v:layoutComplete(function()
            self:_executeItemAnimation(v, false, 1, false)
            self:_clickItem((self._currentIndex and self._currentIndex or 1), false) --UI布局完成后需要设置默认选中效果
        end)
    end

    scrollView:addView(container)
    container:addView(itemsView)

    if not self._progressBar then
        self._progressBar = ImageView():width(10):height(5):cornerRadius(2.5):bgColor(Color(0,0,0))
    end
    self._progressBarWidth = (self._progressBar:width() > 0) and self._progressBar:width() or 10 --处理极端情况：progressBar动画过程中，快速点击tab获取的width是不准的
    container:addView(self._progressBar)
    self._container = container
end

function _class:_clickItem(index, autoAnim)
    if autoAnim and index == self._currentIndex then
        return --多次点击同一个tabItem
    end
    local oldIndex = self._currentIndex
    self._currentIndex = index --尽可能早地更新_currentIndex，处理快速点击的问题
    if self._onSelected and type(self._onSelected) == "function" then
        self._onSelected(index, self._autoAnimTime)
    end
    self:scrollToViewPagerPage(index, self._autoAnimTime)
    self:_updateItemsUI(oldIndex, index, 1, autoAnim)
end

function _class:_updateItemsUI(fromIndex, toIndex, progress, autoAnim)
    if fromIndex and fromIndex > 0 then
        local old = self._subviews[fromIndex]
        self:_executeItemAnimation(old, false, progress, autoAnim)
    end
    local new = self._subviews[toIndex]
    self:_executeItemAnimation(new, true, progress, autoAnim)
    self:_executeProgressBarAnimation(fromIndex, toIndex, progress, autoAnim)
    self:_executeScrollViewOffsetAnimation(toIndex, progress, autoAnim)
end

function _class:_executeProgressBarAnimation(fromIndex, toIndex, progress, autoAnim)
    local fromItem = fromIndex and self._subviews[fromIndex] or nil
    local toItem = self._subviews[toIndex]
    if not toItem then return end

    local anims = self._animCache[self._progressBar]

    if not self._doingFromIndex  then self._doingFromIndex = fromIndex end
    if not self._doingToIndex then self._doingToIndex = toIndex end
    if self._doingFromIndex ~= fromIndex or self._doingToIndex ~= toIndex then
        anims = nil --should recreate animation
    end

    if not anims then
        local posXAnim = ObjectAnimation(AnimProperty.PositionX, self._progressBar)
        local fromValue = fromItem and (CenterX(fromItem) - self._progressBarWidth / 2) or 0
        local toValue = CenterX(toItem) - self._progressBarWidth / 2
        posXAnim:from(fromValue)
        posXAnim:to(toValue)
        posXAnim:duration(self._autoAnimTime)
        posXAnim:finishBlock(function()
            self:_resetProgressBarAnimationFlag() --下次重新创建动画
        end)

        local widthAnimSet = AnimatorSet()
        local widthAnim1 = ObjectAnimation(AnimProperty.ScaleX, self._progressBar)
        local offset = fromItem and math.abs((CenterX(toItem) - CenterX(fromItem)) / (math.abs(toIndex - fromIndex) + 2)) or 0
        local maxWidth = 10 + offset  --10 is initial width
        widthAnim1:from(1)
        widthAnim1:to(maxWidth / 10)
        widthAnim1:duration(self._autoAnimTime / 2)

        local widthAnim2 = ObjectAnimation(AnimProperty.ScaleX, self._progressBar)
        widthAnim2:from(maxWidth / 10)
        widthAnim2:to(1)
        widthAnim2:duration(self._autoAnimTime / 2)

        widthAnimSet:sequentially{widthAnim1, widthAnim2}
        widthAnimSet:finishBlock(function(_)
            self:_resetProgressBarAnimationFlag() --下次重新创建动画
        end)

        anims = {posXAnim, widthAnimSet}
        self._animCache[self._progressBar] = anims
    end

    local posXAnim, widthAnimSet = anims[1], anims[2]

    if autoAnim then
        posXAnim:start()
        widthAnimSet:start()
    else
        posXAnim:update(progress)
        widthAnimSet:update(progress)
        if progress >= 1 then
            self:_resetProgressBarAnimationFlag()
        end
    end
end

function _class:_resetProgressBarAnimationFlag()
    self._animCache[self._progressBar] = nil
    self._doingFromIndex = nil
    self._doingToIndex = nil
end

function _class:_executeScrollViewOffsetAnimation(toIndex, progress, autoAnim)
    local toItem = self._subviews[toIndex]
    if not toItem then return end

    local anim = self._animCache[self.contentView]
    if not anim then
        anim = ObjectAnimation(AnimProperty.ContentOffset, self.contentView)
        anim:finishBlock(function() self._previousContentOffsetX = self.contentView:contentOffset():x() end)
        self._animCache[self.contentView] = anim
    end
    anim:stop() --must stop previous animation

    if not self._previousContentOffsetX then
        self._previousContentOffsetX = 0
    end

    local offset = 0
    local centerX = CenterX(toItem)
    local viewWidth = self.contentView:width()
    local contentSizeWidth = self.contentView:contentSize():width()
    if centerX < viewWidth / 2 then
        offset = 0
    elseif centerX > contentSizeWidth - viewWidth / 2 then
        local contentWidth = (contentSizeWidth > viewWidth) and contentSizeWidth or viewWidth
        offset = contentWidth - viewWidth
    else
        offset = centerX - viewWidth / 2
    end

    anim:from(self._previousContentOffsetX, 0)
    anim:to(offset, 0)

    if autoAnim then
        anim:duration(self._autoAnimTime)
        anim:start()
    else
        anim:update(progress)
        if progress >= 1 then self._previousContentOffsetX = self.contentView:contentOffset():x() end
    end
end

function _class:_executeItemAnimation(tab, positive, progress, auto)
    if not tab then
        return nil
    end

    local anim = self._animCache[tab]
    if not anim then
        if not self._animType then --default tab animation
            self._animType = AnimProperty.Scale
            self._from = {1.0, 1.0}
            self._to = {1.5, 1.5}
        end
        anim = ObjectAnimation(self._animType, tab)
        anim:finishBlock(function() self._isClickTabSegment = false end)
        self._animCache[tab] = anim
    end
    anim:stop() --must stop previous animation

    if positive then
        anim:from(self._from[1], self._from[2], self._from[3], self._from[4])
        anim:to(self._to[1], self._to[2], self._to[3], self._to[4])
    else
        anim:from(self._to[1], self._to[2], self._to[3], self._to[4])
        anim:to(self._from[1], self._from[2], self._from[3], self._from[4])
    end

    if auto then
        anim:duration(self._autoAnimTime)
        anim:start()
    else
        anim:update(progress)
    end
end


function _class:bindViewPager(vpid)
    self._viewpager = vpid
    vpid.segmentSelectedPage = function(fr, to)
        self:setCurrentIndex(to)
    end
    vpid.segmentScrollingListenrer = function(percent, fr, to)
        self:scroll(fr, to, percent)
    end
end

function _class:scrollToViewPagerPage(index, time)
    if self._viewpager then
        self._viewpager:scrollToPage(index, time)
    end
end


---
--- meta
_class.__index = function(t, k)
    local method = _class[k]
    if method ~= nil then
        return method
    end
    local contentView = rawget(t, "contentView")
    if contentView and contentView[k] then
        t.__method = k
        return t
    end
    return method
end

_class.__call = function(t, k, ...)
    local ret = (k.contentView[t.__method])(k.contentView, ...)
    if ret == k.contentView then return t end
    return ret
end

return _class
