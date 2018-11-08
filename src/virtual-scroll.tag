<virtual-scroll>
	/* MIT License

	Copyright (c) 2018 zorgoz

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE. 
	*/
	// tag node pool
	this.pool = document.createDocumentFragment();
	
	// display related properties
	this.nodeBuffer = [];
	this.lastRepaintY = 0;
	this.lastScrolled = 0;
	this.itemHeight = 0; // needs to be set if at least one element is available
	/*private*/totalRows() { return Object.keys(this.items).length; }
	/*private*/height() { return this.root.clientHeight; }
	/*private*/screenItemsLen() { return Math.ceil(this.height() / (this.itemHeight)); }
	/*private*/maxBuffer() { return this.screenItemsLen() * (this.itemHeight); }	
	/*private*/cachedItemsLen() { return this.screenItemsLen() * 3; }

	// get generator
	this.generator = `${this.root.nodeName}-item-${this._riot_id}`.toLowerCase();
	riot.tag(this.generator, this.root.innerHTML, function(opts) { for(var f in opts) this[f]=opts[f]; });
	this.root.innerHTML = '';
	
	/*event*/this.on('mount', () => {		
		// get container padding
		this.compStyles = window.getComputedStyle(this.root);
		this.rootPadding = {
			top: Number(this.compStyles.paddingTop.replace('px','')),
			bottom: Number(this.compStyles.paddingBottom.replace('px','')),
			left: Number(this.compStyles.paddingLeft.replace('px','')),
			right: Number(this.compStyles.paddingRight.replace('px','')),
		}
		
		// create scroller
		this.createScroller();
		this.calculateBounds();
		this.root.addEventListener('scroll', this.onScroll);
		
		// subscribe to resize event
		if(typeof ResizeObserver !== 'undefined'){
			this.ro = new ResizeObserver( entries => {
			  for (let entry of entries) {
				if (entry.target.handleResize) entry.target.handleResize(entry);
			  }
			});

			this.root.handleResize = this.redraw;
			this.ro.observe(this.root);
		} else {
			window.addEventListener('resize', this.redraw);
		}
		
		this.update();
	})
	
	/*event*/this.on('before-unmount', () => {
		riot.unregister(this.generator);
		clearInterval(this.rmNodeInterval);
		
		window.removeEventListener('resize', this.redraw);
		
		if(this.ro) {
			this.ro.disconnect();
		} else {
			window.detachEvent('onresize', this.redraw);
		}
		
		for(var c in this.root.children) if(c.tag) c.tag.unmount();
		for(var c in this.pool.children) if(c.tag) c.tag.unmount();
	})
	
	/*event*/this.on('update', (e) => { 
		this.processOpts(e || this.opts);
		this.calculateBounds();
		this.renderChunk(0);
	})
	
	/*event*/this.on('updated', () => {
		this.root.scrollTop = 0;
		this.lastScrolled = Date.now();
	})
	
	/*public*/locate(the, opts){
		return new Promise((resolve, reject) => {
			if(this.isNumber(the)) {
				the = Number(the);
				if(the < 0 || the >= this.totalRows()) {// out of range
					reject();
					return;
					}
				
				opts = opts || {}
				opts.block = ['start','center','end'].includes(opts.block) ? opts.block : 'center';
				opts.behavior = ['smooth','instant','auto'].includes(opts.behavior) ? opts.behavior : 'auto';				
				
				let sc = the * this.itemHeight + this.rootPadding.top;
				switch(opts.block) {
					case 'center':
						sc -= (this.root.clientHeight - this.itemHeight) / 2;
						break;
					case 'end':
						sc -= this.root.clientHeight - this.itemHeight;
						break;
				}
				sc = Math.max(0, sc);
				
				let sel = `[data-index="${the}"]`;
				let element = this.root.querySelector(sel);
				if(element) {
					resolve(element);					
				} else {
					let react = function() {
						if(!this.nodeBuffer[the]) return;
						element = this.root.querySelector(sel);
						resolve(element);
						this.off('scrolled', react);
					}
				
					this.on('scrolled', react);
				}

				this.root.scroll(Object.assign(opts, {top:sc}));
				return;
			}
			reject();
		})
	}
	
	/*private*/ processOpts(opts){
		this.items = opts.items || this.items || [];
		this.item = opts.item || this.item || 'item';
		this.key = opts.key || this.key ||'key';
		this.index = opts.index || this.index ||'index';
		this.itemClass = opts.itemclass || this.itemClass || null
	}
	
	/*private*/createScroller(h){
		var scroller = document.createElement('div');
		scroller.style.opacity = 0;
		scroller.style.position = 'absolute';
		scroller.style.top = 0;
		scroller.style.left = 0;
		scroller.style.width = '1px';		
		
		this.root.appendChild(scroller)
		this.scroller = scroller;		
	}
	
	/*private*/updateScrollerHeight(){
		this.scroller.style.height = this.itemHeight * this.totalRows() + this.rootPadding.top + this.rootPadding.bottom - this.itemBounds.bottom - this.itemBounds.top/*last one*/ - 20 + 'px';
	}
	
	/*private*/getOne(opts){
		let child;
		if(this.pool.childElementCount) {
			child = this.pool.firstElementChild;
			this.pool.removeChild(child);
			child.tag.update(opts);
		} else {
			child = document.createElement('div');
			let tag = riot.mount(child, this.generator, opts)[0];
			child.tag = tag;		
		}
		
		if(this.itemClass) child.className = this.itemClass;
		child.style.width = this.itemWidth + 'px';
		
		return child;
	}
	
	putOne(child){
		this.pool.appendChild(child);
	}
		
	/*private*/getChildOpts(index){
		let opts = {};
		let key = Object.keys(this.items)[index];
		opts[this.index] = index;
		opts[this.key] = key;
		opts[this.item] = this.items[key];
		return Object.assign({parent:this.parent || this},opts);
	}
		
	/*private*/onScroll(e) {
		e = e || window.event; //ie
		let te = e.target || e.srcElement; //ie
		let scrollTop = te.scrollTop; // Triggers reflow
		if (!this.lastRepaintY || Math.abs(scrollTop - this.lastRepaintY) > this.maxBuffer()) {
			var first = parseInt(scrollTop / this.itemHeight) - this.screenItemsLen();
			this.renderChunk(first < 0 ? 0 : first);
			this.lastRepaintY = scrollTop;
			this.trigger('scrolled', first);
		}

		this.lastScrolled = Date.now();
		e.preventDefault && e.preventDefault();
	}
	
	/*private*/redraw(){
		this.calculateBounds();
		this.root.scrollTo(0, this.rendered.firstVisible * this.itemHeight);
		this.onScroll({target:this.root});
		this.renderChunk(this.rendered.first);
	}
	
	/*private*/calculateBounds(){
		// reset container
		this.nodeBuffer = [];
		while(this.root.childElementCount > 1) { // keep scroller
			this.putOne(this.root.lastElementChild);
		}
		// calculate item size
		let tmp = this.getOne(this.getChildOpts(0));
		tmp.style.visibility = 'hidden';
		this.root.appendChild(tmp);				
		this.itemCompStyles = window.getComputedStyle(tmp);
		this.itemBounds = {
			top: Number(this.itemCompStyles.marginTop.replace('px','')),
			bottom: Number(this.itemCompStyles.marginBottom.replace('px','')),
			left: Number(this.itemCompStyles.marginLeft.replace('px','')),
			right: Number(this.itemCompStyles.marginRight.replace('px','')),
			border: Number(this.itemCompStyles.borderWidth.replace('px','')),
		}	
		
		this.itemHeight = tmp.clientHeight + this.itemBounds.top + this.itemBounds.bottom + this.itemBounds.border*2;		
		this.itemWidth = this.root.clientWidth - this.rootPadding.left - this.rootPadding.right - this.scroller.clientWidth + 1 - this.itemBounds.left - this.itemBounds.right - this.itemBounds.border*2;
		
		tmp.style.visibility = '';
		this.putOne(tmp);
		
		this.updateScrollerHeight();
	}
	
	/*private*/renderChunk(from){
		let finalItem = from + this.cachedItemsLen();
		if (finalItem > this.totalRows()) finalItem = this.totalRows();

		// Append all the new rows in a document fragment that we will later append to
		// the parent node
		let fragment = document.createDocumentFragment();

		for (var i = from; i < finalItem; i++) {
			if(this.nodeBuffer[i]) continue; // skip if in buffer
			
			var child = this.getOne(this.getChildOpts(i))
			child.style.top = i * this.itemHeight + this.rootPadding.top + 'px';
			child.dataset.index = i;
			this.nodeBuffer[i] = child; //store in buffer
			fragment.appendChild(child);
		}

		// Hide and mark obsolete nodes for deletion.
		for (var j = 1; j < this.root.childNodes.length; j++) {
			var child = this.root.childNodes[j];
			if(child.dataset.index && child.dataset.index >= from && child.dataset.index < finalItem) continue;
			
			this.putOne(child);
			j--;
			delete this.nodeBuffer[child.dataset.index];			
		}
		this.root.appendChild(fragment);
		
		this.rendered = { 
			first:from, 
			last: finalItem, 
			firstVisible: Math.round(this.root.scrollTop / this.itemHeight), 
			ratio: this.root.scrollTop / this.root.scrollHeight 
			};
	}
	
	/*private*/isNumber(x){ 
		return (typeof x === 'number' || Number(x).toString() === x) && !isNaN(x) 
	}
	
	// canonized options
	this.processOpts(this.opts);
	<style>
		:scope {
			display: block;
			position: relative;
			overflow-y: auto;
			overflow-x: hidden;
		}
		
		:scope > div {
			position:absolute;
		}
	</style>
</virtual-scroll>