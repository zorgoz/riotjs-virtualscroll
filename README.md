# riotjs-virtualscroll
Virtual scroll component for RiotJs

## Purpose
This small library is itended to deliver a virtual scroll component to the world of RiotJS on client side. It has no dependencies except of RiotJS itself, but it is not a package yet, thus one has to directly include as external script the compiled version from the `dist` folder or the original _tag_ version from the `src` folder.
Contributors are welcome, first of all in transforming it to first-class package and giving it by this backward compatibility also. Right now it requires modern browsers as it is using ES6 syntax.

## Usage
The `<virtual-scroll>` element is a RiotJS tag that has some attributes used by the tag itself. The `innerHTML` of the element is transformed using the `riot.tag` API call into an other tag at runtime before mount - but as it is not complied it has only html, no inner styling or code. Each generated tag has unique name, thus you can use multiple virtual scrolls in one page. When instantiated, the innter tags will be wrapped in a block element (even if the inner content is a tag itself - at least for now). The instantiated inner tags will not show up in the tags property of the component and don't react to the changes of the item they represent.

    <virtual-scroll [item="row"] [key="i"] [index="idx"] [itemClass="myitem"] [items={ riotjs expression }] [other common attributes]>
      Item #{idx}: with key={i}, value={row.value}
    </virtual-scroll>

All attributes are optional. The root parameter of the component is `items` that can be an array or a homogeneous object. It can be passed on mount as option and - when used as nested object - as common riot expression. And of course, on update too. The component will iterate trough the data source by key index, that is passed to the inner tag instance as `index` or as however is overridden in the `index` attribute. The `item` and `key` attributes are likewise meant to override field names passed to the inner instance. The content of `itemClass` will be added as `class` attibute to the inner `div`. The folowing is an example of the emitted inner markup.   

    <div data-is="virtual-scroll-item-0" class="myitem" data-index="4186" style="width: 1343px; top: 251170px;">
      Item #4186: with key=x_4186, value=418600
    </div>

Both the component and the inner blocks have some default styles to allow proper positioning.
**Notes:** 
  - the element node will have a `tag` property set that references the riotjs tag it represents.
  - the inner tag will get as `parent` property of its options the outer tag (if any) and not the component itself; thus you can simply refere to the component's tag context from within its content. 

## Internals
Only at most the triple of the visible content elements is in the DOM at any time to allow smooth scrolling. Mounting and unmounting tags is expensive. To allow good performance, the inner tag instances are reused instead of being unmounted and recreated. The component is using an off-DOM pool that holds a set of elements that are fully prepared to be put back into the component when needed. When scrolling around you will notice that the order of the elements inside the component will become chaotic but positined as required.

The component is taking into account the margins and borders applied to the inner element and the padding applied to the component itself. It recalculates its bounds when updated and when resized. It does _not_ support variable height content. The height is calculated from the element with index `0`, but if you think this method would not be conclusive in any special case, better set fixed height using either the content of `itemClass` or the `virtual-scroll > div` selector.

## Locating elements
You might need to scroll an element into view. As there are few actual inner elements in the DOM at a time, the legacy methods won't work. This is why I have implemented a method for this purpose. The syntax is:

    let vs = ... // the virtual scroll tag object
    vs.locate(index, options).then(function(element) {...})
    
As you probably figured it out already, it returns a promise (an awaitable) as scrolling to a specific item might take a while. At the moment the element is in the DOM, it will resolve immediately. This means that you might get the element before it reaches its final position.

The _index_ parameter is the zero-based index of the item to scroll to within the _items_ collection. If you need to locate an element by property, you will have to calculate the index yourself before calling this method.

_Options_ are optional, and properties similat to that of `element.scroll()` and `element.scrollIntoView()`: `{block:'start|center|end', behavior:'smooth|instant|auto'}`. Defaults are _center_ and _auto_ respectively. The _bahavior_ is actually passed to the DOM method, thus the speed, easing and other physical factors are browser dependent.  

**Live demo: https://jsbin.com/mamafep/edit?output**

_Note_: the demo relies on RiotJS 3.13.1.
