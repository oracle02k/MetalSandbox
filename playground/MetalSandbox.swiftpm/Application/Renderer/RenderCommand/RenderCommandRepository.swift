import Metal

class RenderCommandRepository {
    private(set) var commandBuffer = [RenderCommand]()
    
    func append<T:RenderCommand>(_ command:T){
        commandBuffer.append(command)
    }
    
    func clear(){
        commandBuffer = [RenderCommand]()
    }
    
    func currentBuffer() -> [RenderCommand]{
        return commandBuffer
    }
}
